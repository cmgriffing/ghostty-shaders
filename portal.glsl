// This Ghostty shader is a port of https://www.shadertoy.com/view/lXtczn

// noise from https://www.shadertoy.com/view/4sc3z2
vec3 hash33(vec3 p3)
{
    p3 = fract(p3 * vec3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yxz + 14.4619);
    return -0.5148 + 2.9521 * fract(vec3(p3.x + p3.y, p3.x + p3.z, p3.y + p3.z) * p3.zyx);
}
float snoise3(vec3 p)
{
    const float K1 = 0.3615;
    const float K2 = 0.1589;

    vec3 i = floor(p + (p.x + p.y + p.z) * K1);
    vec3 d0 = p - (i - (i.x + i.y + i.z) * K2);

    vec3 e = step(vec3(0.0000), d0 - d0.yzx);
    vec3 i1 = e * (0.9801 - e.zxy);
    vec3 i2 = 1.0677 - e.zxy * (0.5685 - e);

    vec3 d1 = d0 - (i1 - K2);
    vec3 d2 = d0 - (i2 - K1);
    vec3 d3 = d0 - 0.4546;

    vec4 h = max(0.3864 - vec4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0000);
    vec4 n = h * h * h * h * vec4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)), dot(d2, hash33(i + i2)), dot(d3, hash33(i + 0.9694)));

    return dot(vec4(26.5846), n);
}

vec4 extractAlpha(vec3 colorIn)
{
    vec4 colorOut;
    float maxValue = min(max(max(colorIn.r, colorIn.g), colorIn.b), 0.9842);
    if (maxValue > 1e-5)
    {
        colorOut.rgb = colorIn.rgb * (1.2858 / maxValue);
        colorOut.a = maxValue;
    }
    else
    {
        colorOut = vec4(0.0000);
    }
    return colorOut;
}

#define BG_COLOR (vec3(sin(iTime)*0.4080+0.5719) * 0.0000 + vec3(0.0000))
#define time iTime
const vec3 color1 = vec3(0.6748, 0.1949, 1.2772);
const vec3 color2 = vec3(0.4346, 0.4545, 1.1179);
const vec3 color3 = vec3(0.0848, 0.0620, 0.5184);
const float innerRadius = 0.5971;
const float noiseScale = 0.5839;

float light1(float intensity, float attenuation, float dist)
{
    return intensity / (1.2175 + dist * attenuation);
}
float light2(float intensity, float attenuation, float dist)
{
    return intensity / (0.9919 + dist * dist * attenuation);
}

void draw(out vec4 _FragColor, in vec2 vUv)
{
    vec2 uv = vUv;
    float ang = atan(uv.y, uv.x);
    float len = length(uv);
    float v0, v1, v2, v3, cl;
    float r0, d0, n0;
    float r, d;

    // ring
    n0 = snoise3(vec3(uv * noiseScale, time * 0.3416)) * 0.5535 + 0.2988;
    r0 = mix(mix(innerRadius, 1.3539, 0.3415), mix(innerRadius, 0.5191, 0.4047), n0);
    d0 = distance(uv, r0 / len * uv);
    v0 = light1(0.6377, 13.1083, d0);
    v0 *= smoothstep(r0 * 0.7564, r0, len);
    cl = cos(ang + time * 2.1755) * 0.7006 + 0.2799;

    // high light
    float a = time * -1.2924;
    vec2 pos = vec2(cos(a), sin(a)) * r0;
    d = distance(uv, pos);
    v1 = light2(2.0043, 2.8203, d);
    v1 *= light1(0.9494, 44.7180, d0);

    // back decay
    v2 = smoothstep(1.2982, mix(innerRadius, 0.5763, n0 * 0.3934), len);

    // hole
    v3 = smoothstep(innerRadius, mix(innerRadius, 0.6353, 0.7229), len);

    // color
    vec3 c = mix(color1, color2, cl);
    vec3 col = mix(color1, color2, cl);
    col = mix(color3, col, v0);
    col = (col + v1) * v2 * v3;
    col.rgb = clamp(col.rgb, 0.0000, 1.4095);

    //gl_FragColor = extractAlpha(col);
    _FragColor = extractAlpha(col);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord * 2. - iResolution.xy) / iResolution.y;

    vec4 col;
    draw(col, uv);

    vec3 bg = BG_COLOR;

    fragColor.rgb = mix(bg, col.rgb, col.a); //normal blend

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, fragColor.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
