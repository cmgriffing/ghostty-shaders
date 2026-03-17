import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { convertShader } from './transform.js';
import type { ConversionOptions, ShadertoyApiResponse } from './types.js';

const OVERLAY_MARKER = '// --- Terminal blending (overlay) ---';
const OVERLAY_SAMPLE = 'texture(iChannel0, _termUV)';
const OVERLAY_ASSIGNMENT = 'fragColor = vec4(_blendedColor, _terminalColor.a);';
const OVERLAY_BLOCK_PATTERN =
  /[ \t]*\/\/ --- Terminal blending \(overlay\) ---[\s\S]*?fragColor = vec4\(_blendedColor, _terminalColor\.a\);/m;

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
  const signature =
    /void\s+mainImage\s*\(\s*out\s+vec4\s+\w+\s*,\s*in\s+vec2\s+\w+\s*\)\s*\{/m;
  const match = signature.exec(glsl);
  if (!match) {
    throw new Error('mainImage signature not found in converted output.');
  }

  const bodyStart = match.index + match[0].length;
  let depth = 1;

  for (let i = bodyStart; i < glsl.length; i++) {
    const char = glsl[i];
    if (char === '{') depth++;
    if (char === '}') depth--;
    if (depth === 0) {
      return glsl.slice(bodyStart, i);
    }
  }

  throw new Error('Unable to parse mainImage body (unbalanced braces).');
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

  const assignmentIndex = body.indexOf(OVERLAY_ASSIGNMENT, markerIndex);
  if (assignmentIndex === -1) {
    throw new Error(`${context}: final blended fragColor assignment missing.`);
  }

  const trailingCode = body
    .slice(assignmentIndex + OVERLAY_ASSIGNMENT.length)
    .trim();
  if (trailingCode.length > 0) {
    throw new Error(`${context}: blend assignment is not at end of mainImage body.`);
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
  expectVerifierFailure(misplacedBlend, 'misplaced-overlay-blend');
  console.log('PASS negative: misplaced blend fails verification');

  console.log('Ghostty blend regression verification passed.');
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Ghostty blend regression verification failed: ${message}`);
  process.exit(1);
});
