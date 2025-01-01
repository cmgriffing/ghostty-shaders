// This Ghostty shader is a port of https://www.shadertoy.com/view/4t2cDD

// variant of https://www.shadertoy.com/view/4l2cW1
// golfing PrzemyslawZaworski's https://www.shadertoy.com/view/Xl2yWh

void mainImage(out vec4 O, vec2 U) {
    O *= 0.;
    vec3 p = vec3(iTime, 3, 0) * 9.,
    r = iResolution,
    d = vec3((U - .5 * r.xy) / r.y, 1);
    d.y = -d.y;
    float t = .2;
    for (d.yz *= mat2(4, -3, 3, 4) * t; t > .1; t = min(p.y - 8. * t * t, .2))
        p += t * d, r = ceil(p / 3.),
        O += t = fract(4e4 * sin(r.x + r.z * 17.));
    O /= 2e2;

    vec2 termUV = U.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, O.rgb * 0.3, alpha);

    O = vec4(blendedColor, terminalColor.a);
}
