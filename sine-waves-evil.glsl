// This Ghostty shader is a port of https://www.shadertoy.com/view/l3GGDt

#define pi 3.14159

// GLOW & SDF FROM https://www.shadertoy.com/view/ldKyW1

float glow(float x, float str, float dist) {
    return dist / pow(x, str);
}

// Sinus Signed Distance Function (distance field)
float sinSDF(vec2 st, float A, float offset, float freq, float phi) {
    return abs((st.y - offset) + sin(st.x * freq + phi) * A);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float speed = .4;

    vec3 color = vec3(0.722, 0.855, 1.000);

    vec2 uv = fragCoord.xy / iResolution.xy;

    float time = iTime / 2.0;

    float glowStrength = .6;
    float glowDistance = .02;
    float numWaves = 4.0;

    float col = 0.0;

    for (float i = 0.0; i < numWaves; i++) {
        float phase = (iTime * speed + i * 2.0 * pi / numWaves) * abs(.5 - uv.x) / (.5 - uv.x); // Equally spaced waves moving out from middle
        float frequency = 5.0;
        float amplitude = .15 * abs(uv.x - .5) * (1.0 + i); // Middle = 0, increase outward
        float offset = .5;

        col += glow(sinSDF(uv, amplitude, offset, frequency, phase), glowStrength, glowDistance);
    }

    //col = clamp(abs(.5 - uv.x)/(.5 - uv.x), 0.0, 1.0) + (col * -abs(.5 - uv.x)/(.5 - uv.x));

    //EVIL MODE
    col = 1.0 - col;

    // Output to screen
    fragColor = vec4(vec3(col) * color, 1.0);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, fragColor.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
