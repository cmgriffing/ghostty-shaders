import type { DiagnosticMessage } from './types.js';

interface UniformStub {
  /** Regex to detect usage in source */
  pattern: RegExp;
  /** GLSL #define to inject */
  glsl: string;
  /** Diagnostic message describing the stub */
  message: string;
}

const UNIFORM_STUBS: UniformStub[] = [
  {
    pattern: /\biTimeDelta\b/,
    glsl: '#define iTimeDelta 0.016',
    message: 'Stubbed iTimeDelta as 0.016 (~60fps)',
  },
  {
    pattern: /\biFrameRate\b/,
    glsl: '#define iFrameRate 60.0',
    message: 'Stubbed iFrameRate as 60.0',
  },
  {
    pattern: /\biDate\b/,
    glsl: '#define iDate vec4(2024.0, 0.0, 0.0, iTime)',
    message: 'Stubbed iDate with approximate values',
  },
  {
    pattern: /\biSampleRate\b/,
    glsl: '#define iSampleRate 44100.0',
    message: 'Stubbed iSampleRate as 44100.0',
  },
  {
    pattern: /\biFrame\b/,
    glsl: '#define iFrame int(iTime * 60.0)',
    message: 'Stubbed iFrame as int(iTime * 60.0)',
  },
];

/**
 * Checks whether iMouse is used as a vec4 (with .z, .w, .zw, or swizzles beyond xy).
 */
function needsMouseShim(source: string): boolean {
  if (/\biMouse\s*\.\s*[zwZW]/.test(source)) return true;
  if (/\biMouse\s*\.\s*[xyzw]*[zw][xyzw]*\b/.test(source)) return true;
  if (/vec4\s*\(\s*iMouse\b/.test(source)) return true;
  return false;
}

/**
 * Directly patches iMouse swizzle patterns in source code to account for
 * Ghostty providing vec2 iMouse vs Shadertoy's vec4.
 */
function applyMouseShim(source: string): string {
  // Order matters: longest/most specific patterns first
  source = source.replace(/\biMouse\.xyzw\b/g, 'vec4(iMouse, 0.0, 0.0)');
  source = source.replace(/\biMouse\.xyz\b/g, 'vec3(iMouse, 0.0)');
  source = source.replace(/\biMouse\.zw\b/g, 'vec2(0.0)');
  source = source.replace(/\biMouse\s*\.\s*z\b/g, '0.0');
  source = source.replace(/\biMouse\s*\.\s*w\b/g, '0.0');
  // vec4(iMouse) cast → vec4(iMouse, 0.0, 0.0)
  source = source.replace(/vec4\s*\(\s*iMouse\s*\)/g, 'vec4(iMouse, 0.0, 0.0)');
  return source;
}

/**
 * Scans shader source for Shadertoy uniforms not available in Ghostty
 * and injects compatibility stubs for any that are referenced.
 */
export function stubMissingUniforms(source: string): { code: string; diagnostics: DiagnosticMessage[] } {
  const diagnostics: DiagnosticMessage[] = [];
  let code = source;

  // Step 1: Replace array uniforms inline (can't be #define'd as arrays)
  if (/\biChannelTime\b/.test(code)) {
    code = code.replace(/\biChannelTime\s*\[\s*\d+\s*\]/g, 'iTime');
    diagnostics.push({
      severity: 'info',
      category: 'uniform',
      message: 'Replaced iChannelTime[N] with iTime',
    });
  }

  if (/\biChannelResolution\b/.test(code)) {
    code = code.replace(/\biChannelResolution\s*\[\s*\d+\s*\]/g, 'iResolution');
    diagnostics.push({
      severity: 'info',
      category: 'uniform',
      message: 'Replaced iChannelResolution[N] with iResolution',
    });
  }

  // Step 2: Apply iMouse shim via direct swizzle replacement
  if (/\biMouse\b/.test(code) && needsMouseShim(code)) {
    code = applyMouseShim(code);
    diagnostics.push({
      severity: 'warning',
      category: 'uniform',
      message: 'Applied iMouse vec4 compatibility (Ghostty provides vec2)',
    });
  }

  // Step 3: Collect #define stubs for remaining missing uniforms
  const stubs: string[] = [];
  for (const stub of UNIFORM_STUBS) {
    if (stub.pattern.test(code)) {
      stubs.push(stub.glsl);
      diagnostics.push({
        severity: 'info',
        category: 'uniform',
        message: stub.message,
      });
    }
  }

  if (stubs.length > 0) {
    const stubBlock = '// --- Shadertoy uniform stubs (Ghostty compatibility) ---\n'
      + stubs.join('\n')
      + '\n// --- End uniform stubs ---\n\n';
    code = stubBlock + code;
  }

  return { code, diagnostics };
}

/**
 * Replaces `gl_FragCoord` with `fragCoord` throughout the source.
 * Some Shadertoy shaders use the raw builtin instead of the mainImage parameter.
 */
export function replaceFragCoord(source: string): { code: string; replaced: boolean } {
  const replaced = /\bgl_FragCoord\b/.test(source);
  const code = source.replace(/\bgl_FragCoord\b/g, 'fragCoord');
  return { code, replaced };
}

/**
 * Inserts a Y-axis flip as the first line inside mainImage's body.
 * This accounts for the coordinate system difference between Shadertoy and Ghostty.
 */
export function injectFlipY(source: string): string {
  const mainImagePattern = /(void\s+mainImage\s*\([^)]*\)\s*\{)/;
  const match = source.match(mainImagePattern);

  if (!match) {
    return source;
  }

  return source.replace(
    mainImagePattern,
    '$1\n    fragCoord.y = iResolution.y - fragCoord.y;',
  );
}
