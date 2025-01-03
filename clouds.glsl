// Original shader by Yohei Nishitsuji (https://x.com/YoheiNishitsuji/status/1865218967083847886)
// Adapted for Shadertoy

// 3D Rotation Matrix Generation
mat3 rotate3D(float angle, vec3 axis) {
    vec3 a = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float r = 1.0 - c;
    return mat3(
        a.x * a.x * r + c,
        a.y * a.x * r + a.z * s,
        a.z * a.x * r - a.y * s,
        a.x * a.y * r - a.z * s,
        a.y * a.y * r + c,
        a.z * a.y * r + a.x * s,
        a.x * a.z * r + a.y * s,
        a.y * a.z * r - a.x * s,
        a.z * a.z * r + c
    );
}

// HSV to RGB color conversion
vec3 hsv(float h, float s, float v) {
    vec4 t = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(vec3(h) + t.xyz) * 6.0 - vec3(t.w));
    return v * mix(vec3(t.x), clamp(p - vec3(t.x), 0.0, 1.0), s);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 r = iResolution.xy;
    vec2 FC = fragCoord.xy;
    float t = iTime;
    vec4 o = vec4(0.0, 0.0, 0.0, 1.0);

    // Implements a form of Distance Estimated Ray Marching (DE-RM)
    // with 99 iterations for detailed surface generation
    float i = 0.0;
    float g = 0.0;
    float q = 0.0;
    float s = 0.0;

    for (int j = 0; j < 99; j++) {
        // Initial ray setup with screen-space to world-space transformation
        // Applies 3D rotation for dynamic movement
        vec3 p = vec3((FC.xy - 0.5 * r) / r.y * 7.0 + vec2(-2.0, 8.0), g + 4.0) * rotate3D(sin(t * 0.5) * 0.005 - 1.8, vec3(0.0, 9.0, -1.0));
        p.y = -p.y;

        s = 1.8; // Initial scale factor for the fractal

        // Inner loop: Mandelbulb-inspired fractal iteration
        // Creates a modified Mandelbulb fractal using absolute value operations
        for (int k = 0; k < 19; k++) {
            q = 7.1 / dot(p, p * 0.5);
            p = vec3(0.05, 4.0, -1.0) - abs(abs(p) * q - vec3(3.1, 4.0, 2.9));
            s *= q;
        }

        // Accumulate geometric features
        // g accumulates the y-component weighted by the inverse scale
        // This creates a form of ambient occlusion effect
        g += p.y / s;

        // Final scale adjustment using logarithmic compression
        // This creates a non-linear depth effect and helps prevent overflow
        s = log(s) / exp(q);

        o.rgb += 0.01 - hsv(0.1, g * 0.013, s / 200.0);
        i += 1.0;
    }

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, o.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
