//
// Graphic Designer VS Programmer
// ===========================================================================
//
// *Not super accurate* recreation of the famous
// "Graphic Designer VS Programmer" meme, which can be found here:
// https://www.youtube.com/watch?v=5qHHm7ooavo
//
// NOTE: This shader is a total mess!
//
// Copyright (c) srvstr 2024
// Licensed under MIT
//

const vec3 background_color = vec3(0.824, 0.851, 0.898);

// Colors of the day.
const vec3 primary_cloud_color = vec3(1);
const vec3 secondary_cloud_color = vec3(0.659, 0.792, 0.902);
const vec3[] day_sky_gradient = vec3[](
        vec3(0.38, 0.6, 0.79),
        vec3(0.33, 0.57, 0.77),
        vec3(0.26, 0.51, 0.73),
        vec3(0.18, 0.46, 0.71)
    );
// Each vec3 is sphere with center at XY and radius Z.
// Two arrays of spheres for two layers of clouds.
const vec3[] cloud1 = vec3[](
        vec3(1, -0.5, 1.0),
        vec3(1.2, 0.0, 1.0),
        vec3(0.95, -0.15, 0.7),
        vec3(0.65, -0.45, 0.9),
        vec3(0.35, -0.5, 0.7),
        vec3(0, -0.55, 1.0),
        vec3(-0.4, -0.5, 0.6),
        vec3(-0.7, -0.7, 1.0)),
cloud2 = vec3[](
        vec3(1, -0.5, 1.0),
        vec3(1.2, 0.3, 1.0),
        vec3(0.9, 0.05, 0.7),
        vec3(0.6, -0.2, 1.0),
        vec3(0.25, -0.3, 0.6),
        vec3(0, -0.3, 0.8),
        vec3(-0.35, -0.4, 0.7),
        vec3(-0.75, -0.7, 1.4));

// Colors of the night.
const vec3 moon_base_color = vec3(0.792, 0.808, 0.813);
const vec3 moon_crater_color = vec3(0.635, 0.651, 0.718);
const vec3[] night_sky_gradient = vec3[](
        vec3(0.34, 0.35, 0.38),
        vec3(0.27, 0.28, 0.33),
        vec3(0.2, 0.21, 0.26),
        vec3(0.12, 0.13, 0.19));
const vec3[] stars = vec3[](
        vec3(0.275, 0.25, 3.0),
        vec3(0.2, -0.2, 6.0),
        vec3(0.0, -0.25, 4.0),
        vec3(-0.1, -0.1, 6.0),
        vec3(0, 0.2, 7.0),
        vec3(-0.5, 0.1, 5.0),
        vec3(-0.6, -0.3, 5.0),
        vec3(-0.75, -0.35, 8.0),
        vec3(-0.7, -0.2, 10.0),
        vec3(-0.7, 0.25, 3.0),
        vec3(-0.85, 0.1, 5.0));

// Cubic ease-in-out, mathamatically equivalent to
// GLSL's  `smoothstep()` except the clamping.
float cc(in float x)
{
    float x2 = x * x;
    return 3.0 * x2 - 2.0 * x2 * x;
}

// Recursively nest ease-in-out function
// in order to stepen falloff.
#define CC6(x) cc(CC5(x))
#define CC5(x) cc(CC4(x))
#define CC4(x) cc(CC3(x))
#define CC3(x) cc(CC2(x))
#define CC2(x) cc(cc(x))

// Compute the signed distance field of capsule.
// Source: https://iquilezles.org/articles/distfunctions2d
float sdCapsule(in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Sample lookup table for the background gradient.
vec3 sky_lut(in vec3[4] lut, in vec2 uv)
{
    // Compute LUT index.
    float idx = smoothstep(-0.5, 3.0, dot(uv, uv)) * float(lut.length());
    return lut[min(int(idx), lut.length() - 1)];
}

// Compute color of the background when the sun is shining.
// Additionally consideres clouds.
vec3 sun_bg(in vec2 uv, in float sp)
{
    vec3 sky = sky_lut(day_sky_gradient, uv + vec2(sp, 0));

    vec2 off0 = vec2(0, -sp / 0.75 + 1.0) * 0.5,
    off1 = off0 * off0 * 2.5,
    cloud_mask = vec2(1);

    const vec2 cloud_falloff = vec2(0.3, 0.31);

    for (int i = 0; i < cloud1.length(); i++)
    {
        vec2[] offsets = vec2[](off0, off1);
        vec3[] clouds = vec3[](cloud1[i], cloud2[i]);

        for (int k = 0; k < 2; k++)
        {
            vec2 s = clouds[k].z * cloud_falloff;
            float cloud_df = length(uv + offsets[k] - clouds[k].xy);
            cloud_mask[k] *= smoothstep(s.x, s.y, cloud_df);
        }
    }

    vec3 cloud_color = mix(primary_cloud_color, secondary_cloud_color, cloud_mask.x);
    return mix(cloud_color, sky, cloud_mask.x * cloud_mask.y);
}

// Compute mask for stars.
float star(in vec2 uv, in float scale)
{
    vec2 sp = uv * scale;
    return smoothstep(0.9, 1.0,
        smoothstep(1.0, 0.0,
            abs(sp.x * sp.y) * 5e1)
            * smoothstep(1.0, 0.4, length(sp) * 2.0));
}

// Compute color of the sky at night.
// Additonally consideres stars.
vec3 moon_bg(in vec2 uv, in float sp)
{
    vec3 sky = sky_lut(night_sky_gradient, uv + vec2(sp, 0));

    vec2 off = vec2(0, sp / 0.75 + 1.0) * 0.5;

    for (int i = 0; i < stars.length(); i++)
    {
        // Use non-linear falloff for star of smaller size.
        vec2 rel = stars[i].z > 4.0 ? off : off * off * 2.5;
        float star = star(uv - stars[i].xy - rel, stars[i].z);
        // Screen star mask onto sky.
        sky += (1.0 - sky) * star;
    }

    return sky;
}

// Compute color of the moon.
vec3 moon_fg(in vec2 uv)
{
    vec3 mesh = moon_base_color;

    mesh = mix(mesh,
            moon_crater_color
                * smoothstep(0.3, 0.12, length(uv + vec2(0.1, 0.1))),
            smoothstep(0.16, 0.15, length(uv + vec2(0.1, 0.1))));

    mesh = mix(mesh,
            moon_crater_color
                * smoothstep(0.2, 0.04, length(uv + vec2(0, -0.2))),
            smoothstep(0.08, 0.07, length(uv + vec2(0, -0.2))));

    mesh = mix(mesh,
            moon_crater_color
                * smoothstep(0.2, 0.04, length(uv + vec2(-0.2, 0.1))),
            smoothstep(0.08, 0.07, length(uv + vec2(-0.2, 0.1))));

    return mesh;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float ToD = CC5(cos(iTime * 0.5) * 0.5 + 0.5);

    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y * 2.0;
    uv.y = -uv.y;

    // boundary points of button capsule shape
    vec2 a = vec2(-0.75, 0.0), b = vec2(0.75, 0.0);

    float button_df = sdCapsule(uv, a, b), // distance field of button
    m = smoothstep(0.0, 0.01, button_df - 0.5); // mask of button

    float sp = 0.75 * (ToD * 2.0 - 1.0);

    // celestial bodies (sun/moon)
    vec3 cbs = vec3(0.969, 0.749, 0.126), // sun
    cbm = moon_fg(uv + vec2(sp * 0.4 - 0.45, 0)); // moon

    vec2 of = vec2(sp, 0);

    // celestial body composition
    vec3 cb = mix(cbm, cbs, smoothstep(0.4, 0.41, length(uv + vec2(sp * 0.4 - 0.45, 0))));
    // add highlight
    cb = mix(cb, vec3(1),
            smoothstep(0.3, 0.475, length(uv + of)) *
                smoothstep(0.4, 0.6, length(uv + of + vec2(-0.125, 0.125))));
    // add shadow
    cb = mix(cb, vec3(0.4),
            smoothstep(0.3, 0.5, length(uv + of)) *
                smoothstep(0.4, 0.6, length(uv + of - vec2(-0.125, 0.125))));

    float sm = smoothstep(0.3, 0.43,
            length(uv + vec2(sp, 0) - vec2(0.04, -0.06)))
            * 0.5 + 0.5;

    // background
    vec3 bgs = sun_bg(uv, sp),
    bgm = moon_bg(uv, sp);

    vec3 bg = mix(bgm, bgs, ToD) * sm,
    content = mix(cb,
            // background and inside shadows
            bg * smoothstep(0.7, 0.4, button_df)
                * smoothstep(1.4, 0.7, button_df + uv.y),
            // mask of planet
            smoothstep(0.4, 0.41, length(uv + vec2(sp, 0))));

    vec3 col = mix(content, background_color, m)
            // background highlight
            + (1.0 - smoothstep(-0.1, 0.03, abs(button_df - 0.52)))
                * smoothstep(0.0, 0.4, -uv.y + uv.x * 0.1);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
