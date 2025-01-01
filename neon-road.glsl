#define repid(p, r) (floor((p + r*.5) / r))
#define rep(p, r) (mod(p - r*.5, r) - r*.5)

// Volumetric pointlight by robobo1221
// https://www.shadertoy.com/view/lstfR7
float bayer2(vec2 a) {
    a = floor(a);
    return fract(dot(a, vec2(.5, a.y * .75)));
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))

const float pi = acos(-1.0);
const float pi2 = pi * 2.;

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

vec2 pmod(vec2 p, float r) {
    float a = pi / r - atan(p.x, p.y);
    float n = pi2 / r;
    a = floor(a / n) * n;
    return p * rot(a);
}

float sdHex(vec3 p, vec2 h, float r)
{
    p.zy = p.yz;
    const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
    p = abs(p);
    p.xy -= 2.0 * min(dot(k.xy, p.xy), 0.0) * k.xy;
    vec2 d = vec2(
            length(p.xy - vec2(clamp(p.x, -k.z * h.x, k.z * h.x), h.x)) * sign(p.y - h.x),
            p.z - h.y);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// http://mercury.sexy/hg_sdf/
float ost(float a, float b, float r, float n) {
    float s = r / n;
    float u = b - r;
    return min(min(a, b), 0.5 * (u + a + abs((mod(u - a + s, 2. * s)) - s)));
}

float sdFloor(vec3 p) {
    vec2 hx = vec2(1.73205081, 1) * 1.04;
    vec3 q = p;
    q.xz = mod(p.xz + hx * 0.5, hx) - hx * 0.5;
    float d = sdHex(q, vec2(0.5, 1.0), 0.04);
    q.xz = mod(p.xz, hx) - hx * 0.5;
    d = min(d, sdHex(q, vec2(0.5, 1.0), 0.04));
    return d;
}

float sdWall(vec3 p) {
    vec3 q = p;

    // wall
    float d = -(abs(p.x) - 8.);

    // square
    q = p;
    q.z = rep(q.z, 240.);
    d = max(d, -sdHex(q, vec2(40., 100.), 0.0));

    // pillars
    vec3 pp = p;
    pp.z = rep(pp.z, 240.);

    q.x = abs(q.x) - 7.;
    q.z = rep(q.z, 20.);
    q = abs(q) - 1.0;
    // clipping pillars in square
    d = min(d, max(max(q.x, q.z), -(abs(pp.z) - 40. + 5.0)));

    return d;
}

float sdSquareObjects(vec3 p, float r, out float id) {
    vec3 q = p;

    q.z = rep(q.z, 240.);
    vec3 pp = q;
    q.xz *= rot(pi / 6.);
    q.xz = pmod(q.xz, 6.);
    q.z -= 15.;

    id = repid(q.z, 15.);
    q.z = rep(q.z, 15.);
    float d = length(q.xz) - r;
    d = max(d, -length(pp.xz) + 15. - r);
    return d;
}

float tt;

float sdSquareFrame(vec3 p) {
    float id;
    float d = sdSquareObjects(p, 1.5 + 1., id);
    d = max(d, -(abs(p.y - 13.) - (1.0 - exp(sin(tt * 5. - id * 1.25) * 5.) / exp(5.)) * 5.));
    return d;
}

float sdSquareEmission(vec3 p) {
    float id;
    float d = sdSquareObjects(p, 1.5, id);
    d = max(d, (abs(p.y - 13.) - (1.0 - exp(sin(tt * 5. - id * 1.25) * 5.) / exp(5.)) * 5.));
    return d;
}

float sdCeil(vec3 p) {
    return -(p.y - 30.0);
}

float map(vec3 p) {
    float d = sdFloor(p);

    d = ost(d, sdWall(p), 1.0, 5.0);

    d = min(d, sdSquareFrame(p));

    d = min(d, sdCeil(p));

    return d;
}

vec4 volumeMap0(vec3 p) {
    vec3 q = p;
    q.z = rep(q.z, 30.);
    q.y -= 2.;
    float d = length(q.zy) - .5;
    return vec4(vec3(1., 0.001, .1) * .25, d);
}

vec4 volumeMap1(vec3 p) {
    vec3 q = p;
    q.z = rep(q.z, 30.);
    q.z += 15.;
    q.y -= 20.;
    float d = length(q.zy) - .5;
    return vec4(vec3(.01, 0.01, 1.0) * .4, d);
}

vec4 volumeMap2(vec3 p) {
    vec3 q = p;
    q.z = rep(q.z, 20.);
    q.y -= 12.;
    q.x = abs(q.x) - 6.;
    float d = max(length(q.xy) - .25, abs(q.z) - 3.0);
    return vec4(vec3(.01, 0.01, 1.0) * .3, d);
}

vec4 volumeMap3(vec3 p) {
    float d = sdSquareEmission(p);
    return vec4(vec3(1., 0.01, 0.001) * .2, d);
}

vec3 volumetric(vec3 p, vec3 ray, int slice, float depth, float dither) {
    vec3 ret = vec3(0.);

    float sd = depth / float(slice);
    float t = 0.05 + sd * dither;
    vec4 d;
    for (int i = 0; i < slice; i++) {
        vec3 pos = p + ray * t;
        d = volumeMap0(pos);
        float dd = max(0.01, d.w);
        ret += (d.rgb * sd) / (dd * dd);

        d = volumeMap1(pos);
        dd = max(0.01, d.w);
        ret += (d.rgb * sd) / (dd * dd);

        d = volumeMap2(pos);
        dd = max(0.01, d.w);
        ret += (d.rgb * sd) / (dd * dd);

        d = volumeMap3(pos);
        dd = max(0.01, d.w);
        ret += (d.rgb * sd) / (dd * dd);

        t += sd;
    }
    return ret;
}

void trace(vec3 p, vec3 ray, int iter, out vec3 pos, out float t) {
    t = .1;
    for (int i = 0; i < iter; i++) {
        pos = p + ray * t;
        float d = map(pos);
        if (d < 0.0001) {
            break;
        }
        t += d;
    }
}

vec3 acesFilm(const vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float n3(vec3 p) {
    vec3 r = vec3(1, 99, 999);
    vec4 s = dot(floor(p), r) + vec4(0., r.yz, r.y + r.z);
    p = smoothstep(0., 1., fract(p));
    vec4 a = mix(fract(sin(s) * 5555.), fract(sin(s + 1.) * 5555.), p.x);
    vec2 b = mix(a.xz, a.yw, p.y);
    return mix(b.x, b.y, p.z);
}

vec3 normal(vec3 p) {
    vec2 e = vec2(1., -1.) * 0.001; // 0.005;
    return normalize(e.xyy * map(p + e.xyy) + e.yxy * map(p + e.yxy) + e.yyx * map(p + e.yyx) + e.xxx * map(p + e.xxx));
}

vec3 applyFog(vec3 col, float depth) {
    float fog = 1.0 - exp(-depth * 0.0003);
    col = mix(vec3(col), vec3(1.0, 1.05, 1.8) * 10., fog);
    return col;
}

vec3 getCol(inout vec3 p, vec3 ray, int titer, int viter, float vd, float dither) {
    vec3 col, pos;
    float depth;
    trace(p, ray, titer, pos, depth);
    col += volumetric(p, ray, viter, min(depth, vd), dither);
    p = pos;
    return applyFog(col, depth);
}

float stepup(float t, float len, float smo)
{
    float tt = mod(t += smo, len);
    float stp = floor(t / len) - 1.0;
    return smoothstep(0.0, smo, tt) + stp;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = (fragCoord.xy * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    float nois = (n3(vec3(normalize(p) * 20., 1.0)) * 1.0 + n3(vec3(normalize(p) * 40., 2.0)) * 1.5 + n3(vec3(normalize(p) * 100., 3.0)) * 1.5) / 3.5;
    nois = pow(nois, 4.0) * 2.0 - 1.0;

    tt = iTime + (nois * 0.009 + n3(vec3(p * 500., 0.0)) * 0.004) * pow(dot(p, p), 0.6) * 1.;

    float speed = tt * 100.;

    //speed = stepup(tt, 1.0, 0.5) * 80.;

    vec3 ro = vec3(0., 7., -5. + speed);
    vec3 ray = normalize(vec3(p, 1.4 + (1.0 - dot(p, p)) * 0.15));
    //ray.xy *= rot(stepup(tt-0.5, 4.0, 0.1) * pi * 0.5);

    float dither = bayer16(gl_FragCoord.xy);
    vec3 col = getCol(ro, ray, 99, 120, 300., dither);

    vec3 n = normal(ro);
    ray = reflect(ray, n);
    col += getCol(ro, ray, 60, 70, 100., dither) * 0.2;

    n = normal(ro);
    ray = reflect(ray, n);
    col += getCol(ro, ray, 40, 40, 100., dither) * 0.04;

    col = acesFilm(col * 0.5);

    col = pow(col, vec3(1. / 2.2));

    p = fragCoord.xy / iResolution.xy;
    p *= 1.0 - p.yx;
    float vig = p.x * p.y * 30.0;
    vig = pow(vig, 0.1);

    fragColor = vec4(col * vig, 1.0);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, fragColor.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
