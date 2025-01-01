// This Ghostty shader is a port of https://www.shadertoy.com/view/7s3GWM

// Created by 刘九江 - 刘九江/2021 (network: https://moshuying.github.io)
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// view it (https://www.shadertoy.com/view/7s3GWM)
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = 2. * (fragCoord / iResolution.xy) - 1.;
    float d = uv.y + mod(iTime / 4., .5) - 1.8 + .65 / 2.;

    float dd = length(uv);
    float cuxi = 60.;
    float strongD = uv.y + mod(iTime / 2., .5) - 1.8 + .65 / 2.;
    vec3 stronge = (vec3(0.95, 0.25, 1.) + uv.y / 4. - 0.3) / (cuxi * abs(strongD));

    vec3 col;
    col += stronge;

    for (float i = 1.; i < 13.; i++) {
        col += (vec3(0.65, 0.25, 1.) + uv.y / 4. - 0.3) / (cuxi * abs(d + i * .25));
    }

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
