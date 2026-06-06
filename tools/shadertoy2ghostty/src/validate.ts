import { createRequire } from 'module';
import { execFile } from 'child_process';
import { writeFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import type { DiagnosticMessage } from './types.js';

const require = createRequire(import.meta.url);

// ---------------------------------------------------------------------------
// Tier 1: Structural validation (zero deps, always runs)
// ---------------------------------------------------------------------------

export function validateStructural(glsl: string): DiagnosticMessage[] {
  const diagnostics: DiagnosticMessage[] = [];

  // Check mainImage signature exists
  if (!/void\s+mainImage\s*\(\s*out\s+vec4\s+\w+\s*,\s*in\s+vec2\s+\w+\s*\)/.test(glsl)) {
    diagnostics.push({
      severity: 'error',
      category: 'general',
      message: 'Missing mainImage(out vec4, in vec2) function signature.',
    });
  }

  // Check balanced braces (comment-aware)
  let braceDepth = 0;
  let inSingleLineComment = false;
  let inMultiLineComment = false;
  for (let i = 0; i < glsl.length; i++) {
    const ch = glsl[i];
    const nextCh = glsl[i + 1];

    if (inSingleLineComment) {
      if (ch === '\n') {
        inSingleLineComment = false;
      }
      continue;
    }
    if (inMultiLineComment) {
      if (ch === '*' && nextCh === '/') {
        inMultiLineComment = false;
        i++;
      }
      continue;
    }

    if (ch === '/' && nextCh === '/') {
      inSingleLineComment = true;
      i++;
      continue;
    }
    if (ch === '/' && nextCh === '*') {
      inMultiLineComment = true;
      i++;
      continue;
    }

    if (ch === '{') braceDepth++;
    if (ch === '}') braceDepth--;
    if (braceDepth < 0) break;
  }
  if (braceDepth !== 0) {
    diagnostics.push({
      severity: 'error',
      category: 'general',
      message: `Unbalanced braces (depth off by ${braceDepth}).`,
    });
  }

  // Check balanced parentheses (comment-aware)
  let parenDepth = 0;
  inSingleLineComment = false;
  inMultiLineComment = false;
  for (let i = 0; i < glsl.length; i++) {
    const ch = glsl[i];
    const nextCh = glsl[i + 1];

    if (inSingleLineComment) {
      if (ch === '\n') {
        inSingleLineComment = false;
      }
      continue;
    }
    if (inMultiLineComment) {
      if (ch === '*' && nextCh === '/') {
        inMultiLineComment = false;
        i++;
      }
      continue;
    }

    if (ch === '/' && nextCh === '/') {
      inSingleLineComment = true;
      i++;
      continue;
    }
    if (ch === '/' && nextCh === '*') {
      inMultiLineComment = true;
      i++;
      continue;
    }

    if (ch === '(') parenDepth++;
    if (ch === ')') parenDepth--;
    if (parenDepth < 0) break;
  }
  if (parenDepth !== 0) {
    diagnostics.push({
      severity: 'error',
      category: 'general',
      message: `Unbalanced parentheses (depth off by ${parenDepth}).`,
    });
  }

  // Check for leftover Shadertoy artifacts
  if (/\bgl_FragCoord\b/.test(glsl)) {
    diagnostics.push({
      severity: 'warning',
      category: 'general',
      message: 'gl_FragCoord found in output — should have been replaced with fragCoord.',
    });
  }

  if (/\bgl_FragColor\b/.test(glsl)) {
    diagnostics.push({
      severity: 'warning',
      category: 'general',
      message: 'gl_FragColor found in output — Ghostty uses fragColor out parameter.',
    });
  }

  if (/^#version\b/m.test(glsl)) {
    diagnostics.push({
      severity: 'warning',
      category: 'general',
      message: '#version directive found — Ghostty manages this automatically.',
    });
  }

  // Check for empty mainImage body
  const mainImageBody = glsl.match(/void\s+mainImage\s*\([^)]*\)\s*\{([\s\S]*?)\}/);
  if (mainImageBody && mainImageBody[1].trim() === '') {
    diagnostics.push({
      severity: 'error',
      category: 'general',
      message: 'mainImage has an empty body.',
    });
  }

  return diagnostics;
}

// ---------------------------------------------------------------------------
// Tier 2: AST parsing via glsl-tokenizer + glsl-parser
// ---------------------------------------------------------------------------

export function validateAST(glsl: string): DiagnosticMessage[] {
  const diagnostics: DiagnosticMessage[] = [];

  // Strip comment lines starting with // at the very top (attribution header)
  // but keep #define lines since the parser handles preprocessor directives
  try {
    const tokenize = require('glsl-tokenizer/string');
    const parse = require('glsl-parser/direct');

    const tokens = tokenize(glsl);
    parse(tokens);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    diagnostics.push({
      severity: 'error',
      category: 'general',
      message: `GLSL parse error: ${message}`,
    });
  }

  return diagnostics;
}

// ---------------------------------------------------------------------------
// Tier 3: glslangValidator (opt-in, requires system tool)
// ---------------------------------------------------------------------------

function findGlslangValidator(): string | null {
  const candidates = [
    '/opt/homebrew/bin/glslangValidator',
    '/usr/local/bin/glslangValidator',
    '/usr/bin/glslangValidator',
  ];

  // Also try PATH via which
  try {
    const { execFileSync } = require('child_process');
    const result = execFileSync('which', ['glslangValidator'], {
      encoding: 'utf-8',
      timeout: 2000,
    }).trim();
    if (result) return result;
  } catch {
    // not in PATH
  }

  for (const p of candidates) {
    try {
      const { statSync } = require('fs');
      statSync(p);
      return p;
    } catch {
      // not found
    }
  }

  return null;
}

/**
 * Wraps the shader in a minimal fragment shader harness for glslangValidator.
 * Ghostty provides these uniforms, so we need to declare them for standalone compilation.
 */
function wrapForValidation(glsl: string): string {
  const harness = `#version 330 core
precision highp float;

uniform float iTime;
uniform vec3 iResolution;
uniform vec2 iMouse;
uniform sampler2D iChannel0;

out vec4 _fragOutput;

`;
  // Replace mainImage call pattern: inject a main() that calls mainImage
  const footer = `
void main() {
    vec4 fragColor;
    vec2 fragCoord = gl_FragCoord.xy;
    mainImage(fragColor, fragCoord);
    _fragOutput = fragColor;
}
`;

  return harness + glsl + footer;
}

export async function validateWithGlslang(glsl: string): Promise<DiagnosticMessage[]> {
  const diagnostics: DiagnosticMessage[] = [];

  const validatorPath = findGlslangValidator();
  if (!validatorPath) {
    diagnostics.push({
      severity: 'warning',
      category: 'general',
      message: 'glslangValidator not found. Install with: brew install glslang',
    });
    return diagnostics;
  }

  const wrapped = wrapForValidation(glsl);
  const tmpPath = join(tmpdir(), `shadertoy2ghostty-validate-${Date.now()}.frag`);

  try {
    writeFileSync(tmpPath, wrapped, 'utf-8');

    const result = await new Promise<{ stdout: string; stderr: string; code: number }>((resolve) => {
      execFile(validatorPath, [tmpPath], { timeout: 10000 }, (err, stdout, stderr) => {
        resolve({
          stdout: stdout || '',
          stderr: stderr || '',
          code: err && 'code' in err ? (err as { code: number }).code : 0,
        });
      });
    });

    const output = result.stdout + result.stderr;

    if (output.includes('ERROR:')) {
      // Parse error lines — format: "ERROR: file:line: message"
      const errorLines = output.split('\n').filter(l => l.includes('ERROR:'));
      for (const line of errorLines) {
        // Adjust line numbers: subtract harness lines
        const match = line.match(/ERROR:\s*\S+:(\d+):\s*(.*)/);
        if (match) {
          const harnessLines = 10; // lines in our harness before the user code
          const adjustedLine = Math.max(1, parseInt(match[1], 10) - harnessLines);
          diagnostics.push({
            severity: 'error',
            category: 'general',
            message: `glslang: line ${adjustedLine}: ${match[2].trim()}`,
          });
        } else {
          diagnostics.push({
            severity: 'error',
            category: 'general',
            message: `glslang: ${line.replace('ERROR:', '').trim()}`,
          });
        }
      }
    }

    if (output.includes('WARNING:')) {
      const warnLines = output.split('\n').filter(l => l.includes('WARNING:'));
      for (const line of warnLines) {
        diagnostics.push({
          severity: 'warning',
          category: 'general',
          message: `glslang: ${line.replace('WARNING:', '').trim()}`,
        });
      }
    }
  } finally {
    try { unlinkSync(tmpPath); } catch { /* ignore */ }
  }

  return diagnostics;
}
