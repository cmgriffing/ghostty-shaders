import assert from 'node:assert/strict';
import { convertShader } from './transform.js';
import { validateStructural } from './validate.js';
import type { ConversionOptions, ShadertoyApiResponse } from './types.js';

function wrapRawGlsl(code: string, name: string): ShadertoyApiResponse {
  return {
    Shader: {
      ver: '0.1',
      info: {
        id: 'local',
        date: '',
        viewed: 0,
        name,
        username: 'local',
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

const options: ConversionOptions = {
  blendMode: 'replace',
  flipY: true,
  force: false,
  verbose: false,
  analyzeOnly: false,
  validate: false,
};

async function verifyLocalMainConversion(): Promise<void> {
  const localMainShader = wrapRawGlsl(
    `void main() {
  gl_FragColor = vec4(1.0, 0.2, 0.4, 1.0);
}`,
    'local-main',
  );

  const convertedLocalMain = await convertShader(localMainShader, options);
  assert.match(
    convertedLocalMain.glsl,
    /void\s+mainImage\s*\(\s*out\s+vec4\s+fragColor\s*,\s*in\s+vec2\s+fragCoord\s*\)/,
    'Local main() input must be normalized to mainImage(out vec4 fragColor, in vec2 fragCoord).',
  );
  assert.ok(
    !/\bgl_FragColor\b/.test(convertedLocalMain.glsl),
    'Converted local main() output must not contain gl_FragColor.',
  );

  const localMainStructuralDiagnostics = validateStructural(convertedLocalMain.glsl);
  assert.ok(
    !localMainStructuralDiagnostics.some((d) => d.message.includes('Missing mainImage')),
    'Converted local main() output should satisfy mainImage structural checks.',
  );
  assert.ok(
    !localMainStructuralDiagnostics.some((d) => d.message.includes('gl_FragColor found')),
    'Converted local main() output should pass gl_FragColor structural checks.',
  );
}

async function verifyExistingMainImageInput(): Promise<void> {
  const mainImageShader = wrapRawGlsl(
    `void mainImage(out vec4 color, in vec2 uv) {
  color = vec4(uv / iResolution.xy, 0.0, 1.0);
}`,
    'existing-mainimage',
  );

  const convertedMainImage = await convertShader(mainImageShader, options);
  assert.match(
    convertedMainImage.glsl,
    /void\s+mainImage\s*\(\s*out\s+vec4\s+color\s*,\s*in\s+vec2\s+uv\s*\)/,
    'Standard mainImage inputs should be preserved.',
  );
}

async function main(): Promise<void> {
  await verifyLocalMainConversion();
  await verifyExistingMainImageInput();
  console.log('verify:local-main passed');
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
