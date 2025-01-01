// This Ghostty shader is a port of https://www.shadertoy.com/view/3dS3zV

#define PROFILE 0

// #define DO_ROT
// #define DO_LOGROT

#define ISO 0.4

#if PROFILE==0
#define STEP 0.01
#define EULER 5
#else
#define STEP 0.1
#define EULER 3
#endif

// -- Chladni plasma
const float pi = 3.1415926535897932384;

// Knot numbers
vec2 mn = vec2(5.0, 3.0);

#if 0
float chladni(vec2 mn, vec2 uv)
{
    return cos(mn.x * pi * uv.x) * cos(mn.y * pi * uv.y);
}

float density(vec3 p)
{
    vec2 uv = p.xy;

    // Superposition coefficients
    float alpha = iTime;
    mat2 R = mat2(cos(alpha), sin(alpha), -sin(alpha), cos(alpha));
    vec2 c = R * vec2(1.0, -1.0);

    // Superposition of eigenmodes
    float u = c.x * chladni(mn.xy, uv) + c.y * chladni(mn.yx, uv); // chladni(p.zx,uv);
    //u += 0.5*chladni(sqrt(mn.xy*mn.yx),R*p.zy);

    return 100.0 * u;
}

vec3 warp(vec3 p)
{
    mat3 d = mat3(0.0001);
    return vec3(
        density(p - d[0]) - density(p + d[0]),
        density(p - d[1]) - density(p + d[1]),
        density(p - d[2]) - density(p + d[2])
    );
}
#else
float fun(vec2 uv, vec2 mn, vec2 c)
{
    return c.x * cos(pi * mn.x * uv.x) * cos(pi * mn.y * uv.y)
        + c.y * cos(pi * mn.y * uv.x) * cos(pi * mn.x * uv.y);
}

vec2 dfun(vec2 uv, vec2 mn, vec2 c)
{
    // scaling not correct
    return vec2(-c.x * sin(pi * mn.x * uv.x) * cos(pi * mn.y * uv.y)
            - c.y * sin(pi * mn.y * uv.x) * cos(pi * mn.x * uv.y),
        -c.x * cos(pi * mn.x * uv.x) * sin(pi * mn.y * uv.y)
            - c.y * cos(pi * mn.y * uv.x) * sin(pi * mn.x * uv.y));
}

vec3 warp(vec3 p)
{
    vec2 uv = p.xy;

    // Superposition coefficients
    float alpha = iTime;
    mat2 R = mat2(cos(alpha), sin(alpha), -sin(alpha), cos(alpha));
    vec2 c = R * vec2(1.0, -1.0);

    return 0.3 * vec3(dfun(uv, mn, c), 0);
}
#endif

// --- Stationary velocity field(s)
vec3 svf(vec3 x)
{
    vec3 svf0, svf1;

    // Warp field
    svf0 = warp(x);

    #ifndef DO_LOGROT
    svf1 = vec3(0);
    #else
    // Log affine transformation (evaluated off-line)
    // Central rotation around x
    vec3 center = vec3(0.0);
    float w = 1.0 - smoothstep(0.1, 2.0, length(x - center));
    float lambda0 = -5.0 + 10.0 * iMouse.x / iResolution.x;
    float logt = lambda0;
    mat4 L = transpose(mat4( // matrices are given column-major
                0.0, 0.0, 0.0, 0.0,
                0.0, 0.0, logt, 0.0,
                0.0, -logt, 0.0, 0.0,
                0.0, 0.0, 0.0, 0.0));
    vec3 v = (L * vec4(x - center, 1.0)).xyz - L[3].xyz;
    svf1 = w * (-v);
    #endif
    return svf0 + svf1;
}

// Compute vectorfield exponential via Euler-step algorithm
vec3 integrate(vec3 x0, float sign_, int steps)
{
    vec3 x = x0;
    float h = 1.0 / float(steps); // stepsize
    for (int k = 0; k < steps; k++) // Euler steps
    {
        x = x + h * sign_ * svf(x);
    }
    return (x - x0);
}

mat3 rodrigues(vec3 r, float theta)
{
    float s = sin(theta);
    float c = cos(theta);
    float t = 1.0 - c;
    return mat3(
        t * r.x * r.x + c, t * r.x * r.y - s * r.z, t * r.x * r.y + s * r.y,
        t * r.x * r.y + s * r.z, t * r.y * r.y + c, t * r.y * r.z - s * r.x,
        t * r.x * r.z - s * r.y, t * r.x * r.y + s * r.x, t * r.z * r.z + c
    );
}

vec3 trafo(vec3 p)
{
    p += integrate(p, -1.0, EULER);
    #ifndef DO_ROT
    return p;
    #else
    mat3 Rx = rodrigues(normalize(vec3(1.0, 0.0, 0.0)), 3.14 * iTime * 0.1);
    mat3 Ry = rodrigues(normalize(vec3(0.0, 1.0, 0.0)), 3.14 * iTime * 0.1);
    return Rx * Ry * p;
    #endif
}

// https://iquilezles.org/articles/distfunctions
float sdRoundBox(vec3 p, vec3 b, float r)
{
    vec3 d = abs(p) - b;
    return length(max(d, 0.0)) - r
        + min(max(d.x, max(d.y, d.z)), 0.0); // remove this line for an only partially signed sdf
}

float sdOctahedron(in vec3 p, in float s)
{
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

float sdTorus(vec3 p, vec2 t)
{
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float field(vec3 p)
{
    p = trafo(p);

    return dot(p, p);
    //return max(max(abs(p.x),abs(p.y)),abs(p.z));
    //return p.x*p.x + p.z*p.z;

    //return sdTorus( p, vec2(0.2,0.1) );
    //return sdOctahedron( p, 0.2 );
    //return sdRoundBox( p, vec3(0.3), 0.01 );
}

vec3 grad(vec3 p)
{
    mat3 d = mat3(0.01);
    return vec3(
        field(p - d[0]) - field(p + d[0]),
        field(p - d[1]) - field(p + d[1]),
        field(p - d[2]) - field(p + d[2])
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    #if 0
    if (mod(fragCoord.x, 2.0) <= 1.0)
    {
        fragColor = vec4(0);

        vec2 termUV = fragCoord.xy / iResolution.xy;
        vec4 terminalColor = texture(iChannel0, termUV);

        float alpha = step(length(terminalColor.rgb), 0.4);
        vec3 blendedColor = mix(terminalColor.rgb * 1.0, fragColor.rgb * 0.3, alpha);

        fragColor = vec4(blendedColor, terminalColor.a);
        return;
    }
    #endif

    // normalized pixel coordinate
    vec2 npc = 2.0 * fragCoord / iResolution.xy - vec2(1.0, 1.0);
    npc.y /= iResolution.x / iResolution.y;

    #ifdef IS_CINESHADER
    npc *= 0.6;
    #endif

    vec3 bg = .5 * vec3(.6, .5, 1) * (1.0 - npc.y * npc.y) * mod(fragCoord.y, 2.0);

    if (sqrt(npc.x * npc.x + npc.y * npc.y) > 0.5)
    {
        // fragColor = vec4(bg, 0);

        vec2 termUV = fragCoord.xy / iResolution.xy;
        vec4 terminalColor = texture(iChannel0, termUV);

        float alpha = step(length(terminalColor.rgb), 0.4);
        vec3 blendedColor = mix(terminalColor.rgb * 1.0, bg.rgb * 0.3, alpha);

        fragColor = vec4(blendedColor, terminalColor.a);
        return;
    }

    float s = iTime * 0.1;
    mn = 3.0 * vec2(sin(1.3 * s + .3) + 1.0, cos(s) + 1.0) + 2.0 * vec2(cos(s * .1 + .7) + 1.0);

    vec3 p0 = vec3(npc, -1.0);
    vec3 eye = vec3(0.0, 0.0, -2.0);
    vec3 dir = normalize(p0 - eye);

    vec4 dst = vec4(bg, 0.);

    float ds = STEP;
    for (float s = 0.0; s < 2.0; s += ds)
    {
        vec3 p = p0 + s * dir;
        float val = field(p);

        // isosurface
        if (val < ISO)
        {
            vec3 rd = vec3(.6, .5, 1);
            vec3 rs = vec3(1, 1, 0);

            vec3 l = normalize(vec3(0.5, -0.5, 1.0));
            vec3 n = normalize(grad(p));
            vec3 h = normalize(0.5 * (l + dir));
            dst = vec4(rd * max(0.0, dot(n, l)) + rs * (pow(dot(h, n), 42.0)), 1.0 - s);
            break;
        }
    }

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, dst.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}

/** SHADERDATA
{
	"title": "svfwarp",
	"description": "A raymarched sphere deformed by a Chladni velocity field",
	"model": "person"
}
*/
