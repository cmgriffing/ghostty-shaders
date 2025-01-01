// This Ghostty shader is a port of https://www.shadertoy.com/view/4fVfR1

// All SDFs by Inigo Quilez

float sdEquilateralTriangle(in vec2 p, in float r)
{
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}

float sdSegment(in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdCircle(vec2 p, float r)
{
    return length(p) - r;
}

float sdBox(in vec2 p, in vec2 b)
{
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p;
    return fract(p);
}

float cityLayer(vec2 p, float d, float top, float btm) {
    float t = floor(p.x * d);
    float h = hash11(t + d * 183.32) * (top - btm) + btm;
    if (p.y < h) {
        return 1.;
    } else if (hash11(t + d * 381.23) > .8) {
        float r = floor(hash11(t + d * 38353.1) * 4.);
        // Special tops of buildings
        if (r == 0.) {
            vec2 bp = vec2(t / d, h);
            vec2 up = vec2(t / d, h + .05);
            return smoothstep(0., 0.001, clamp(1. - sdSegment(p, bp, up) * 50., 0., 1.));
        } else if (r == 1.) {
            p.x -= (t + .5) / d;
            p.y -= h;
            return smoothstep(0., 0.3, clamp(1. - sdEquilateralTriangle(p, 1. / d) * 500., 0., 1.));
        } else if (r == 2.) {
            p.x -= (t + .5) / d;
            p.y -= h;
            return smoothstep(0., .3, clamp(1. - sdCircle(p, 1. / d) * 500., 0., 1.));
        } else if (r == 3.) {
            vec2 bp = vec2((t + .5) / d, h);
            vec2 up = vec2((t + .5) / d, h + .05);
            return smoothstep(0., 0.1, clamp(1. - sdSegment(p, bp, up) * 500., 0., 1.));
        }
    }
    return 0.;
}

float city(vec2 p, int n, float top, float btm, float t) {
    float ogX = p.x;
    float val = 0.;
    for (int i = 0; i < n; i++) {
        p.x += iTime * (float(i) * 0.1 + 0.2) / float(n);
        float addVal = 1. * (1. - float(i) / (float(n)));
        float c = cityLayer(
                p,
                t - float(i) * t / (float(n) * 2.),
                top - float(i) * (top - btm) / (float(n) * 2.),
                btm + (float(n) - float(i)) * (top - btm) / (float(n) * 2.)
            );

        if (c != 0.) {
            val = val * (1. - c) + addVal * c;
        }
        p.x = ogX;
    }

    return val;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float density = 0.1;
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.y;
    uv.y = -uv.y;
    // Time varying pixel color
    uv.y += 0.7;

    vec3 col = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0, 2, 4));
    bool underwater = false;
    if (uv.y < 0.) {
        uv.y = abs(uv.y);
        uv.x += sin(uv.y * 200. + iTime * 10.) * .002;
        underwater = true;
    }
    float c = city(uv, 10, .4, 0., 16.);
    if (underwater) {
        col = (c * .5 + .5) * vec3(1., .4, .4);
    } else {
        col = (c * .5 + .5) * vec3(1., .4, 0.);
    }

    // Output to screen

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
