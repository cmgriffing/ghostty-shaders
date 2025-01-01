/* Elevator to infinity by @kishimisu (2023)  -  https://www.shadertoy.com/view/mddfW8
   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (https://creativecommons.org/licenses/by-nc-sa/4.0/deed.en)
   *****************************************

     Move the camera with the mouse!

   Alternative audio versions:

   I couldn't decide which audio and camera movement was the best for this scene,
   so I preferred to keep this shader simple and fork the other ideas I liked:

   - Audio-reactive lights:                    https://www.shadertoy.com/view/DddBWM
   - Longer camera anim + dark ambient music:  https://www.shadertoy.com/view/csdBD7
   - Speed increase synced with music buildup: https://www.shadertoy.com/view/dddBWM


   This is my first successful attempt at raymarching infinite buildings.
   In my previous attempts, I was adding details using domain repetition for
   nearly all raymarching operators and it was too hard to maintain.

   In this version, I started with a simpler task, which is to generate only one
   floor using regular raymarching, and then use domain repetition at the very
   beginning to repeat the floor infinitely, thus creating infinite buildings.

   Do you have tips to reduce flickering in the distance ?
*/

// Comment out to disable all lights except elevators
#define LIGHTS_ON

float acc = 0.; // Neon light accumulation
float occ = 1.; // Ambient occlusion (Fake)

// 2D rotation
#define rot(a) mat2(cos(a), -sin(a), sin(a), cos(a))

// Domain rep.
#define rep(p, r) mod(p+r, r+r)-r

// Domain rep. ID
#define rid(p, r) floor((p+r)/(r+r))

// Finite domain rep.
#define lrep(p, r, l) p-r*clamp(round(p/r), -l, l)

// Fast random noise 2 -> 3
vec3 hash(vec2 p) {
    vec2 r = fract(sin(p * mat2(137.1, 12.7, 74.7, 269.5)) * 43478.5453);
    return vec3(r, fract(r.x * r.y * 1121.67));
}
// Random noise 3 -> 3 - https://shadertoyunofficial.wordpress.com/2019/01/02/
#define hash33(p) fract(sin(p*mat3(127.1,311.7,74.7,269.5,183.3,246.1,113.5,271.9,124.6))*43758.5453123)

// Distance functions - https://iquilezles.org/articles/distfunctions/
float box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}
float rect(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.)) + min(max(d.x, d.y), 0.);
}

#define ext 2.
float opElevatorWindows(vec3 p, float b) {
    float e = box(p, vec3(ext * .8, 2.7, .3));
    float lv = length(p.xz) - .1;
    p.y += 1.;
    float lh = length(p.yz) - .1;
    lh = max(b, lh);
    b = max(b, -e);
    b = min(b, min(lv, lh));
    return b;
}

float building(vec3 p0, vec3 p, float L) {
    float B = rect(p.xz, vec2(L, 10)); // Main building
    float B2 = rect(vec2(abs(p.x) - L - ext, p.z), vec2(ext, 10)); // Elevator building

    // (Optim) Skip building calculations
    if (min(B, B2) > .2) return min(B, B2);

    vec3 q = p;
    float var = step(1., mod(rid(p.y, 3.), 6.)); // Railing variation
    p.y = rep(p.y, 3.); // Infinite floor y-repetition
    vec3 pb = vec3(abs(p.x), p.yz);

    #ifdef LIGHTS_ON
    // Building lights
    vec3 id = rid(vec3(q.xy, p0.z), vec3(21, 18, 48));
    vec3 rn = hash33(id);
    float rw = fract(rn.x * rn.z * 1021.67);

    q.x += 14. * (rn.x * 3. - 1.);
    q.y += 12. * (floor(rn.y * 3.) - 1.);
    q.xy = rep(q.xy, vec2(21, 18));

    float l = box(q, vec3(mix(3., 15., rw), rn.z * 1.5 + .5, 7));
    acc += .5 / (1. + pow(abs(l) * 20., 1.5))
            * smoothstep(0., .4, iTime - rw * 20.)
            * step(p0.x, 10. + 2e2 * step(20., abs(p0.z)));
    #endif

    // Occlusion
    occ = min(occ, smoothstep(3.5, 0., -rect(p.xz, vec2(L + 2., 10))));
    occ = min(occ, smoothstep(0.6, 0., -rect(pb.xz - vec2(L + ext, 0), vec2(ext, 10))));

    // Front hole
    q = p;
    q.x = rep(q.x, 7.);
    q.y -= (1. - var) * 1.01;

    float f = box(q + vec3(0, 0, 10), vec3(6.6, 2. + var, 3));
    B = max(B, -f);
    B = max(B, -rect(q.xz + vec2(0, 10), vec2(6.6, .7) * var));

    // Railing
    q = p;
    q.x = rep(q.x, .8);

    float r = length(p.yz + vec2(1, 9.5 - var * .5)) - .2;
    float rv = length(q.xz + vec2(0, 9.5 - var * .5)) - .16;
    r = min(r, rv);
    r = max(r, p.y + 1.);

    // Back bars
    q = p;
    q.x = rep(q.x, 1.75);

    float b = length(q.xz + vec2(0, 7.3)) - .2;
    r = min(r, b);

    B = min(B, r);
    B = max(B, abs(p.x) - L);

    // (Optim) Skip elevator calculations
    if (B2 > .04) return min(B, B2);

    // Elevator
    B2 = opElevatorWindows(pb - vec3(L + ext, 0, -9.9), B2);
    B2 = opElevatorWindows(vec3(pb.z + 8., pb.y, pb.x - L - ext - 1.9), B2);

    // Side windows
    q = vec3(pb.xy, pb.z - 1.8);
    q.z = lrep(q.z, 2.5, 2.);

    float w = box(q - vec3(L + ext * 2., 1.2, 0), vec3(.5, 1.6, 1.2));
    B2 = max(B2, -w);

    return min(B, B2);
}

float map(vec3 p) {
    vec2 id = vec2(step(40., p.x), rid(p.z, 140.));
    vec3 rn = mix(vec3(1, -.5, 0), hash(id), step(.5, id.x + id.y));

    // Buildings
    vec3 p0 = p;
    p.x = abs(abs(p.x - 40.) - 80.);
    p.z = rep(p.z - id.x * 200., 200.);

    float bL = 21.4 + id.y * 3.;
    float b1 = building(p0, p - vec3(30, 0, 0), bL);
    float b2 = building(p0, vec3(p.z, p.y, -p.x), 185.);

    // Elevator lights
    float rpy = 80. + 150. * rn.x;
    ;
    p.y = rep(p.y - iTime * 40. * (rn.y * .5 + .5), rpy);
    p -= vec3(30. + bL + ext, rn.z * rpy * .5, ext - 10.);

    float l = box(p, vec3(ext * .8, 2.7, ext * .8));
    acc += .5 / (1. + pow(abs(l) * 18., 1.17));

    // Fix broken distance before 20s
    b2 = min(b2, abs(p0.x + p0.z - 30.) + 6.);

    return min(b1, b2);
}

// https://iquilezles.org/articles/normalsSDF/
vec3 normal(vec3 p) {
    const vec2 k = vec2(1, -1) * .0001;
    return normalize(k.xyy * map(p + k.xyy) + k.yyx * map(p + k.yyx) +
            k.yxy * map(p + k.yxy) + k.xxx * map(p + k.xxx));
}

void mainImage(out vec4 O, vec2 F) {
    vec2 R = iResolution.xy,
    u = (F + F - R) / R.y,
    M = iMouse.xy / R * 2. - 1.;
    u.y = -u.y;
    M *= step(1., iMouse.z);

    // Camera animation
    float T = 1. - pow(1. - clamp(iTime * .025, 0., 1.), 3.);
    float ax = mix(-.8, .36, T);
    float az = mix(-40., -140., T);
    float rx = M.x * .45 - (cos(iTime * .1) * .5 + .5) * .4;
    rx = clamp(ax + rx - .55, min(iTime * .05 - 1.6, -.9), .1);

    // Ray origin & direction
    vec3 ro = vec3(0, iTime * 10., az);
    vec3 rd = normalize(vec3(u, 3));

    rd.zy *= rot(M.y * 1.3);
    rd.zx *= rot(rx);
    ro.zx *= rot(rx);

    // Raymarching
    vec3 p;
    float d, t = 0.;
    for (int i = 0; i < 60; i++) {
        p = ro + t * rd;
        t += d = map(p);
        if (d < .01 || t > 2200.) break;
    }

    // Base color
    vec3 col = vec3(.13, .11, .26) - vec3(1, 1, 0) * abs(p.x - 40.) * .001;
    col *= clamp(1. + dot(normal(p), normalize(vec3(0, 0, 1))), .5, 1.);

    // Texture
    col *= 1. - texture(iChannel0, vec2(p.x + p.z, p.y + p.z) * .05).rgb * .7;

    // Occlusion
    col *= occ;

    // Exponential fog
    col = mix(vec3(.002, .005, .015), col, exp(-t * .0025 * vec3(.8, 1, 1.2) - length(u) * .5));

    // Light accumulation
    col += acc * mix(vec3(1, .97, .76), vec3(1, .57, .36), t * .0006);

    // Color correction
    col = pow(col, .46 * vec3(.98, .96, 1));

    // Vignette
    u = F / R;
    u *= 1. - u.yx;
    col *= pow(clamp(u.x * u.y * 80., 0., 1.), .2);

    vec2 termUV = F.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    O = vec4(blendedColor, terminalColor.a);
}
