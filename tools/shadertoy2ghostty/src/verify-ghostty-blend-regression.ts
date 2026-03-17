import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { convertShader } from './transform.js';
import type { ConversionOptions, ShadertoyApiResponse } from './types.js';

const OVERLAY_MARKER = '// --- Terminal blending (overlay) ---';
const OVERLAY_SAMPLE = 'texture(iChannel0, _termUV)';
const FLIP_Y_STATEMENT_PATTERN = /fragCoord\.y\s*=\s*iResolution\.y\s*-\s*fragCoord\.y\s*;/;
const TERM_UV_ASSIGNMENT_PATTERN = /vec2\s+_termUV\s*=\s*([^;]+);/;
const Y_COMPENSATION_PATTERN = /iResolution\.y\s*-\s*fragCoord\.y/;
const OVERLAY_BLOCK_PATTERN =
  /[ \t]*\/\/ --- Terminal blending \(overlay\) ---[\s\S]*?fragColor\s*=\s*vec4\([^;]+\)\s*;/m;

interface Fixture {
  name: string;
  fileName: string;
}

const FIXTURES: Fixture[] = [
  { name: 'simple-main-image', fileName: 'simple-main-image.frag' },
  { name: 'main-image-trailing-helper', fileName: 'main-image-trailing-helper.frag' },
];

const CONVERSION_OPTIONS: ConversionOptions = {
  blendMode: 'overlay',
  flipY: true,
  force: false,
  verbose: false,
  analyzeOnly: false,
  validate: false,
};

function wrapRawGlsl(code: string, name: string): ShadertoyApiResponse {
  return {
    Shader: {
      ver: '0.1',
      info: {
        id: 'local',
        date: '',
        viewed: 0,
        name,
        username: 'regression',
        description: '',
        likes: 0,
        published: 0,
        flags: 0,
        usePreview: 0,
        tags: [],
        hasliked: 0,
      },
      renderpass: [
        {
          inputs: [],
          outputs: [{ id: 0, channel: 0 }],
          code,
          name: 'Image',
          description: '',
          type: 'image',
        },
      ],
    },
  };
}

function getMainImageBody(glsl: string): string {
  const { bodyStart, bodyEnd } = findFunctionBodyBounds(
    glsl,
    /void\s+mainImage\s*\(\s*out\s+vec4\s+\w+\s*,\s*in\s+vec2\s+\w+\s*\)\s*\{/m,
    'mainImage',
  );
  return glsl.slice(bodyStart, bodyEnd);
}

function findFunctionBodyBounds(
  glsl: string,
  signature: RegExp,
  label: string,
): { bodyStart: number; bodyEnd: number } {
  const match = signature.exec(glsl);
  if (!match || match.index === undefined) {
    throw new Error(`${label} signature not found in converted output.`);
  }

  const openBraceIndex = match.index + match[0].length - 1;
  const bodyStart = openBraceIndex + 1;
  let depth = 1;

  for (let i = bodyStart; i < glsl.length; i++) {
    const char = glsl[i];
    if (char === '{') depth++;
    if (char === '}') depth--;
    if (depth === 0) {
      return { bodyStart, bodyEnd: i };
    }
  }

  throw new Error(`Unable to parse ${label} body (unbalanced braces).`);
}

function assertGhosttyBlendPlacement(glsl: string, context: string): void {
  const body = getMainImageBody(glsl);
  const markerIndex = body.indexOf(OVERLAY_MARKER);
  if (markerIndex === -1) {
    throw new Error(`${context}: overlay blend marker missing from mainImage.`);
  }

  const sampleIndex = body.indexOf(OVERLAY_SAMPLE, markerIndex);
  if (sampleIndex === -1) {
    throw new Error(`${context}: iChannel0 sampling missing from blend block.`);
  }

  const overlayBlock = getOverlayBlock(body, context);
  const assignmentIndex = body.indexOf(overlayBlock, markerIndex);

  const trailingCode = body
    .slice(assignmentIndex + overlayBlock.length)
    .trim();
  if (trailingCode.length > 0) {
    throw new Error(`${context}: blend assignment is not at end of mainImage body.`);
  }

  assertTerminalLayerOrientation(body, context);
  assertFinalCompositionVisibility(overlayBlock, context);
}

function getOverlayBlock(mainImageBody: string, context: string): string {
  const match = mainImageBody.match(OVERLAY_BLOCK_PATTERN);
  if (!match) {
    throw new Error(`${context}: overlay blend block not found in mainImage body.`);
  }

  return match[0];
}

function findLineIndex(lines: string[], pattern: RegExp, startIndex = 0): number {
  for (let i = startIndex; i < lines.length; i++) {
    if (pattern.test(lines[i])) {
      return i;
    }
  }
  return -1;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function findNearestVec2Assignment(
  lines: string[],
  variableName: string,
  beforeLineIndex: number,
): { expression: string; lineIndex: number } | null {
  const pattern = new RegExp(`\\bvec2\\s+${escapeRegExp(variableName)}\\s*=\\s*([^;]+);`);
  for (let i = beforeLineIndex - 1; i >= 0; i--) {
    const match = lines[i].match(pattern);
    if (match) {
      return { expression: match[1], lineIndex: i };
    }
  }
  return null;
}

function classifyTermUvExpression(
  expression: string,
  expressionLineIndex: number,
  lines: string[],
  flipLineIndex: number,
  visited = new Set<string>(),
  depth = 0,
): 'unflipped' | 'flipped' | 'unknown' {
  if (depth > 5) {
    return 'unknown';
  }

  const normalized = expression.replace(/\s+/g, ' ').trim();

  if (Y_COMPENSATION_PATTERN.test(normalized)) {
    return 'unflipped';
  }

  if (
    /fragCoord\.xy\s*\/\s*iResolution\.xy/.test(normalized)
    || /vec2\s*\(\s*fragCoord\.x\s*,\s*fragCoord\.y\s*\)\s*\/\s*iResolution\.xy/.test(normalized)
  ) {
    if (flipLineIndex !== -1 && flipLineIndex < expressionLineIndex) {
      return 'flipped';
    }
    return 'unflipped';
  }

  const variableReferenceMatch = normalized.match(
    /^([A-Za-z_][A-Za-z0-9_]*)(?:\.xy)?(?:\s*\/\s*iResolution\.xy)?$/,
  );
  if (!variableReferenceMatch) {
    return 'unknown';
  }

  const variableName = variableReferenceMatch[1];
  if (visited.has(variableName)) {
    return 'unknown';
  }
  visited.add(variableName);

  const assignment = findNearestVec2Assignment(lines, variableName, expressionLineIndex);
  if (!assignment) {
    return 'unknown';
  }

  return classifyTermUvExpression(
    assignment.expression,
    assignment.lineIndex,
    lines,
    flipLineIndex,
    visited,
    depth + 1,
  );
}

function assertTerminalLayerOrientation(mainImageBody: string, context: string): void {
  const lines = mainImageBody.split(/\r?\n/);
  const markerLineIndex = findLineIndex(lines, /\/\/ --- Terminal blending \(overlay\) ---/);
  if (markerLineIndex === -1) {
    throw new Error(`${context}: overlay marker line missing.`);
  }

  const termUvLineIndex = findLineIndex(lines, TERM_UV_ASSIGNMENT_PATTERN, markerLineIndex);
  if (termUvLineIndex === -1) {
    throw new Error(`${context}: _termUV assignment missing from overlay block.`);
  }

  const termUvMatch = lines[termUvLineIndex].match(TERM_UV_ASSIGNMENT_PATTERN);
  if (!termUvMatch) {
    throw new Error(`${context}: unable to parse _termUV assignment.`);
  }

  const flipLineIndex = findLineIndex(lines, FLIP_Y_STATEMENT_PATTERN);
  if (flipLineIndex === -1) {
    throw new Error(`${context}: expected flip-Y statement in mainImage body.`);
  }

  const classification = classifyTermUvExpression(
    termUvMatch[1],
    termUvLineIndex,
    lines,
    flipLineIndex,
  );

  if (classification === 'flipped') {
    throw new Error(`${context}: terminal sampling uses flipped coordinates (inverted terminal layer).`);
  }

  if (classification === 'unknown') {
    throw new Error(`${context}: unable to verify terminal sampling orientation.`);
  }
}

interface Assignment {
  name: string;
  expression: string;
  lineIndex: number;
}

function parseAssignments(lines: string[], beforeLineIndex: number): Assignment[] {
  const assignments: Assignment[] = [];
  const assignmentPattern = /\b(?:float|vec2|vec3|vec4)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);/;

  for (let i = 0; i < beforeLineIndex; i++) {
    const match = lines[i].match(assignmentPattern);
    if (match) {
      assignments.push({
        name: match[1],
        expression: match[2],
        lineIndex: i,
      });
    }
  }

  return assignments;
}

function findLatestAssignment(
  assignments: Assignment[],
  variableName: string,
  beforeLineIndex: number,
): Assignment | null {
  for (let i = assignments.length - 1; i >= 0; i--) {
    const assignment = assignments[i];
    if (assignment.name === variableName && assignment.lineIndex < beforeLineIndex) {
      return assignment;
    }
  }
  return null;
}

function expandExpression(
  expression: string,
  assignments: Assignment[],
  beforeLineIndex: number,
  depth = 0,
  resolving = new Set<string>(),
): string {
  if (depth > 6) {
    return expression;
  }

  return expression.replace(/\b([A-Za-z_][A-Za-z0-9_]*)\b/g, (token, variableName) => {
    const assignment = findLatestAssignment(assignments, variableName, beforeLineIndex);
    if (!assignment) {
      return token;
    }

    const key = `${variableName}:${assignment.lineIndex}`;
    if (resolving.has(key)) {
      return token;
    }

    resolving.add(key);
    const expanded = expandExpression(
      assignment.expression,
      assignments,
      assignment.lineIndex,
      depth + 1,
      resolving,
    );
    resolving.delete(key);

    return `(${expanded})`;
  });
}

function splitTopLevelArguments(args: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let start = 0;

  for (let i = 0; i < args.length; i++) {
    const char = args[i];
    if (char === '(') depth++;
    if (char === ')') depth--;
    if (char === ',' && depth === 0) {
      parts.push(args.slice(start, i).trim());
      start = i + 1;
    }
  }

  parts.push(args.slice(start).trim());
  return parts.filter((part) => part.length > 0);
}

function extractFinalVec4Args(overlayBlock: string, context: string): { rgb: string; alpha: string; lineIndex: number } {
  const lines = overlayBlock.split(/\r?\n/);
  let finalLineIndex = -1;
  let finalLine = '';

  for (let i = 0; i < lines.length; i++) {
    if (/fragColor\s*=\s*vec4\s*\(/.test(lines[i])) {
      finalLineIndex = i;
      finalLine = lines[i];
    }
  }

  if (finalLineIndex === -1) {
    throw new Error(`${context}: final vec4 assignment missing from overlay block.`);
  }

  const argsMatch = finalLine.match(/fragColor\s*=\s*vec4\s*\(([^;]+)\)\s*;/);
  if (!argsMatch) {
    throw new Error(`${context}: unable to parse final vec4 assignment.`);
  }

  const args = splitTopLevelArguments(argsMatch[1]);
  if (args.length === 2) {
    return { rgb: args[0], alpha: args[1], lineIndex: finalLineIndex };
  }
  if (args.length === 4) {
    return {
      rgb: `${args[0]}, ${args[1]}, ${args[2]}`,
      alpha: args[3],
      lineIndex: finalLineIndex,
    };
  }

  throw new Error(`${context}: unsupported vec4 argument shape in final assignment.`);
}

function assertFinalCompositionVisibility(overlayBlock: string, context: string): void {
  const lines = overlayBlock.split(/\r?\n/);
  const finalArgs = extractFinalVec4Args(overlayBlock, context);
  const assignments = parseAssignments(lines, finalArgs.lineIndex + 1);

  const expandedRgb = expandExpression(finalArgs.rgb, assignments, finalArgs.lineIndex + 1);
  const expandedAlpha = expandExpression(finalArgs.alpha, assignments, finalArgs.lineIndex + 1);

  const hasTerminalContribution = /_terminalColor\.rgb/.test(expandedRgb);
  const hasShaderContribution = /\bfragColor\.rgb\b/.test(expandedRgb);
  if (!hasTerminalContribution || !hasShaderContribution) {
    throw new Error(
      `${context}: final composition must preserve both terminal RGB and shader RGB contributions.`,
    );
  }

  if (!/_terminalColor\.a/.test(expandedAlpha)) {
    throw new Error(`${context}: final composition must preserve terminal alpha for readability.`);
  }
}

function removeOverlayBlend(glsl: string): string {
  if (!OVERLAY_BLOCK_PATTERN.test(glsl)) {
    throw new Error('Unable to remove blend block: overlay block not found.');
  }
  return glsl.replace(OVERLAY_BLOCK_PATTERN, '');
}

function moveOverlayBlendOutsideMainImage(glsl: string): string {
  const match = glsl.match(OVERLAY_BLOCK_PATTERN);
  if (!match) {
    throw new Error('Unable to move blend block: overlay block not found.');
  }

  const withoutBlend = glsl.replace(OVERLAY_BLOCK_PATTERN, '');
  return `${withoutBlend}\n${match[0]}\n`;
}

function moveOverlayBlendIntoTrailingHelper(glsl: string): string {
  const match = glsl.match(OVERLAY_BLOCK_PATTERN);
  if (!match) {
    throw new Error('Unable to move blend block into helper: overlay block not found.');
  }

  const withoutBlend = glsl.replace(OVERLAY_BLOCK_PATTERN, '');
  const { bodyEnd } = findFunctionBodyBounds(
    withoutBlend,
    /float\s+helperPulse\s*\(\s*vec2\s+\w+\s*\)\s*\{/m,
    'helperPulse',
  );

  const inserted =
    withoutBlend.slice(0, bodyEnd)
    + `\n${match[0]}\n`
    + withoutBlend.slice(bodyEnd);

  const helperBody = (() => {
    const bounds = findFunctionBodyBounds(
      inserted,
      /float\s+helperPulse\s*\(\s*vec2\s+\w+\s*\)\s*\{/m,
      'helperPulse',
    );
    return inserted.slice(bounds.bodyStart, bounds.bodyEnd);
  })();

  if (!helperBody.includes(OVERLAY_MARKER)) {
    throw new Error('Failed to inject overlay block into helperPulse.');
  }

  return inserted;
}

function forceInvertedTerminalSampling(glsl: string): string {
  const termUvPattern = /vec2\s+_termUV\s*=\s*[^;]+;/;
  if (!termUvPattern.test(glsl)) {
    throw new Error('Unable to force inversion: _termUV assignment not found.');
  }

  return glsl.replace(termUvPattern, 'vec2 _termUV = fragCoord.xy / iResolution.xy;');
}

function forceHiddenShaderContribution(glsl: string): string {
  const blendedPattern = /vec3\s+_blendedColor\s*=\s*[^;]+;/;
  if (!blendedPattern.test(glsl)) {
    throw new Error('Unable to hide shader contribution: _blendedColor assignment not found.');
  }

  return glsl.replace(blendedPattern, 'vec3 _blendedColor = _terminalColor.rgb;');
}

function forceHiddenTerminalContribution(glsl: string): string {
  const blendedPattern = /vec3\s+_blendedColor\s*=\s*[^;]+;/;
  if (!blendedPattern.test(glsl)) {
    throw new Error('Unable to hide terminal contribution: _blendedColor assignment not found.');
  }

  return glsl.replace(blendedPattern, 'vec3 _blendedColor = fragColor.rgb;');
}

function expectVerifierFailure(glsl: string, context: string): void {
  let threw = false;
  try {
    assertGhosttyBlendPlacement(glsl, context);
  } catch {
    threw = true;
  }

  if (!threw) {
    throw new Error(`${context}: expected verifier failure, but verification passed.`);
  }
}

async function convertFixture(fixture: Fixture): Promise<string> {
  const srcDir = path.dirname(fileURLToPath(import.meta.url));
  const fixturePath = path.resolve(srcDir, '../fixtures', fixture.fileName);
  const source = fs.readFileSync(fixturePath, 'utf8');
  const shader = wrapRawGlsl(source, fixture.name);
  const result = await convertShader(shader, CONVERSION_OPTIONS);
  return result.glsl;
}

async function main(): Promise<void> {
  const converted = new Map<string, string>();

  for (const fixture of FIXTURES) {
    const glsl = await convertFixture(fixture);
    assertGhosttyBlendPlacement(glsl, fixture.name);
    converted.set(fixture.name, glsl);
    console.log(`PASS fixture: ${fixture.name}`);
  }

  const baseline = converted.get('simple-main-image');
  if (!baseline) {
    throw new Error('simple-main-image baseline conversion missing.');
  }

  const missingBlend = removeOverlayBlend(baseline);
  expectVerifierFailure(missingBlend, 'missing-overlay-blend');
  console.log('PASS negative: missing blend fails verification');

  const misplacedBlend = moveOverlayBlendOutsideMainImage(baseline);
  expectVerifierFailure(misplacedBlend, 'misplaced-overlay-blend-outside-mainimage');
  console.log('PASS negative: blend moved outside mainImage fails verification');

  const trailingHelperBaseline = converted.get('main-image-trailing-helper');
  if (!trailingHelperBaseline) {
    throw new Error('main-image-trailing-helper baseline conversion missing.');
  }

  const helperInjectedBlend = moveOverlayBlendIntoTrailingHelper(trailingHelperBaseline);
  expectVerifierFailure(helperInjectedBlend, 'misplaced-overlay-blend-in-trailing-helper');
  console.log('PASS negative: blend injected into trailing helper fails verification');

  const invertedSampling = forceInvertedTerminalSampling(baseline);
  expectVerifierFailure(invertedSampling, 'inverted-terminal-sampling');
  console.log('PASS negative: inverted terminal sampling fails verification');

  const shaderHidden = forceHiddenShaderContribution(baseline);
  expectVerifierFailure(shaderHidden, 'shader-contribution-hidden');
  console.log('PASS negative: hidden shader contribution fails verification');

  const terminalHidden = forceHiddenTerminalContribution(baseline);
  expectVerifierFailure(terminalHidden, 'terminal-contribution-hidden');
  console.log('PASS negative: hidden terminal contribution fails verification');

  console.log('Ghostty blend regression verification passed.');
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Ghostty blend regression verification failed: ${message}`);
  process.exit(1);
});
