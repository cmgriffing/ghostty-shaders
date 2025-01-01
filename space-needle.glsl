// This Ghostty shader is a port of https://www.shadertoy.com/view/mdGSDG

// HAPPY BIRTHDAY SHINING MONSTER!!! THANKS FOR YOUR FRIENDSHIP :)

// If music doesn't work press pause on iChannel1 below and play again

float det = .01;
vec3 objcol;

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, s, -s, c);
}

float hash(vec2 p)
{
    p *= 1000.;
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(float x) {
    float fr = fract(x);
    float fl = floor(x);
    return mix(hash(vec2(fl)), hash(vec2(fl + 1.)), smoothstep(0., 1., fr));
}

float box(vec3 p, vec3 c) {
    p = abs(p) - c;
    return length(max(vec3(0.), p));
}

float cyl(vec3 p, float r, float h, float d, float e, float f) {
    p.y *= f;
    vec3 pp = p;

    pp.y += h;
    r += pow(abs(pp.y), e) * d;
    return max(abs(p.y) - h, length(p.xz) - r);
}

void radialCopy(inout vec2 p, float cant, float offset)
{
    float d = 3.1416 / cant * 2.;
    float at = atan(p.y, p.x);
    float a = mod(at, d) - d * .5;
    p = vec2(cos(a), sin(a)) * length(p) - vec2(offset, 0.);
}

float glass(vec3 p) {
    vec3 p1 = p, p2 = p, p3 = p;
    p.y += 2.8;
    p.xz *= 1. - p.y * .03;
    radialCopy(p.xz, 40., 8.5);
    float d = box(p, vec3(.3, .88, .5));
    p1.y += 5.;
    p1.xz *= 1. - p1.y * .05;
    radialCopy(p1.xz, 30., 7.);
    d = min(d, box(p1, vec3(.3, .8, .6)));
    p2.y -= 2.3;
    return d * .5;
}

float head(vec3 p) {
    p.y -= 1.;
    vec3 p1 = p;
    p1.y -= 1.;
    float d = cyl(p1, 3.7, .2, 1., 1.2, -1.);
    d = min(d, cyl(p, 3., .8, .4, 2., 1.));
    p.y += 1.5;
    d = min(d, cyl(p, 3., 1.2, 2., 1.2, -1.));
    vec3 p2 = p;
    p2.y += 3.;
    p2.y = abs(p2.y);
    d = min(d, cyl(p2, 8.3, .5, 5., 1., -1.));
    vec3 p3 = p;
    p3.y += 5.7;
    p3.y = abs(p3.y);
    d = min(d, cyl(p3, 7., .5, 2., 1., -1.));
    vec3 p4 = p;
    p4.y -= 4.;
    d = min(d, cyl(p4, .8, 1., 0.2, 1., -1.));
    p.y += 3.;
    d = min(d, cyl(p, 7., 2., 0., 1., 1.));
    return d * .5;
}

float tower(vec3 p) {
    vec3 p1 = p;
    radialCopy(p.xz, 3., 2.);
    p.xz *= rot(radians(90.));
    p.y *= .8;
    p.x *= 1.2;
    p.y += 25.;
    float y = p.y - 10.;
    p.z += y * (10. + y) * .007;
    float r = y * (20. + y * 2.) * .005 * (.1 + smoothstep(-10., 0., y));
    r *= 1. + y * .02;
    float d = box(p, vec3(1.5 + r, 20., .2));
    p.y -= 24.;
    float hue1 = length(p.xy * vec2(5., 1.)) - 13.;
    d = max(d, -hue1 * .5);
    p.y += 41.;
    float hue2 = length(p.xy * vec2(15., 1.)) - 19.;
    d = max(d, -hue2 * .1);
    p1.xz *= rot(radians(60.));
    radialCopy(p1.xz, 3., 2.);
    p1.y += 36.;
    d = min(d, box(p1, vec3(.2, .5, 1.5)));
    p.y = mod(p.y, 3.) - 1.5;
    float esc = box(p, vec3(1.2, .2, .2));
    esc = max(esc, y);
    esc = max(esc, -y - 30.);
    d = min(d, esc);
    return d * .8;
}

float center(vec3 p) {
    float a = length(p.xz) - .6 + p.y * .05;
    a = max(a, -p.y);
    vec3 p2 = p, p3 = p;
    p2.y = mod(p2.y, 1.5) - .75;
    float d = max(abs(p.y + 25.) - 25., box(p2, vec3(1., .2, .2)));
    p2.xz *= .9;
    d = min(d, max(max(abs(p.y + 30.) - 25., length(p2.xz) - .85 - abs(.5 - fract(atan(p.x, p.z)))), -length(p2.xz) + 1.2));
    d = min(d, a);
    p3.y -= 2.5;
    p3.xz *= 1. + p3.y * .1;
    radialCopy(p3.xz, 21., 3.);
    d = min(d, box(p3, vec3(.3, .8, .4)));
    return d;
}

float de(vec3 p) {
    p.xz *= rot(-.3);
    objcol = vec3(.95, .85, .8) * .8;
    p.y -= 15.;
    float hea = head(p);
    float gla = glass(p);
    float tow = tower(p) * .5;
    float cen = center(p);
    float d = min(tow, min(hea, gla));
    if (d == gla) objcol = vec3(.8, .9, 1.) * .65;
    d = min(d, cen);
    if (d == cen) objcol = vec3(.4, .35, .3);
    return d;
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0., det);
    return normalize(vec3(de(p + e.yxx), de(p + e.xyx), de(p + e.xxy)) - de(p));
}

vec2 line(in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

vec3 background(vec2 uv) {
    vec2 p = (gl_FragCoord.xy - iResolution.xy * .5) / iResolution.y;
    p = uv * 5.;
    vec2 p2 = p;
    float id1 = floor(p.x * 7.) * 120.123;
    float id2 = floor(p.x * 3.5);
    float h = floor(hash(vec2(id1)) * step(.12, hash(vec2(id2))) * 14. * 1.5) / (14. * 1.5);
    vec3 sky = vec3(.9, .8, .7) * (.7 + mod(gl_FragCoord.y, 5.) * .05);
    sky -= smoothstep(-.38, -.4, p.y + noise(uv.x * 30.) * .07) * .2 * vec3(1.5, 1., 0.5);
    //h-=step(fract(p.x*7.),.05);
    float skyline = step(-.75 + h * .8, p.y);
    vec3 col = mix(vec3(-p.y * .25) + .1, sky, skyline);
    vec2 id = floor(p * 14. * 1.5);
    vec2 v = fract(p * 14. * 1.5 - .125);
    skyline = step(-.77 + h * .8, p.y);
    col += step(length(max(vec2(0.), abs(v) - .7)), 0.) *
            (1. - skyline) * .3 * hash(id) * step(.6, hash(id)) * step(-.9, p.y) * vec3(1., .8, .7);
    col.rb *= rot(clamp(-.5, .0, -p2.y * .15 - .05) * 2.);
    col.b *= .95;
    col *= .5 + smoothstep(1.3, 0., p.y) * .5;
    vec2 l = line(p, vec2(-.5, .03), vec2(.5, .6));
    float tt = iTime - 15.;
    float tr = 1. - l.y * 2. - tt * 4. + 2.;
    col = mix(col, vec3(.8), smoothstep(.01, .0, l.x) * smoothstep(0., 1., fract(tr) * step(0., tr) * step(tr, 1.)));
    float st = hash(floor(p * 80.) / 80.);
    col += step(.999, st) * clamp(p.y + .7, 0., 1.) * .11 * st * st;
    return col;
}

vec3 march(vec3 from, vec3 dir) {
    vec3 p, col = background(dir.xy);
    float d, td = 0., maxdist = 150.;
    float g = 0.;
    for (int i = 0; i < 150; i++) {
        p = from + dir * td;
        d = de(p);
        if (d < det || td > maxdist) break;
        td += d;
        g += .1 / (.1 + d * 10.);
    }
    if (d < det) {
        p -= dir * det * 2.;
        vec3 n = normal(p);
        vec3 ldir = normalize(vec3(.9, 1., -1.));
        col = objcol * (smoothstep(.5, .55, max(0., dot(ldir, n))) * .45 + .85);
    } else td = maxdist;
    return col - g * .015;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - iResolution.xy * .5) / iResolution.y;
    uv.y = -uv.y;
    vec3 col = vec3(0.), dir;
    for (float i = 0.; i < 4.; i++) {
        uv += vec2(mod(i, 2.), floor(i / 2.)) / iResolution.xy * .8;
        float a = smoothstep(-2., 2., sin((iTime + 14.) * .15));
        vec3 from = vec3(-23., 4. + a * 3., -120.);
        dir = normalize(vec3(uv, 2. + a));
        from.x += a * a * 20.;
        from.xz *= rot(a * a);
        dir.xz *= rot(a * a);
        col += march(from, dir);
    }
    col /= 4.;
    col *= vec3(1., .95, .9) * 1.1 - hash(uv + floor(mod(iTime, 10.) * 15.) * .2) * .15;
    col = pow(col, vec3(1.4));
    col *= smoothstep(0., 4., iTime);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
