// This Ghostty shader is a port of https://www.shadertoy.com/view/4scGWj

// Port of Humus Electro demo http://humus.name/index.php?page=3D&ID=35
// Not exactly right as the noise is wrong, but is the closest I could make it.
// Uses Simplex noise by Nikita Miropolskiy https://www.shadertoy.com/view/XsX3zB

/* Simplex code license
 * This work is licensed under a
 * Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
 * http://creativecommons.org/licenses/by-nc-sa/3.0/
 *  - You must attribute the work in the source code
 *    (link to https://www.shadertoy.com/view/XsX3zB).
 *  - You may not use this work for commercial purposes.
 *  - You may distribute a derivative work only under the same license.
 */

/* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
vec3 random3(vec3 c) {
    float j = 4096.0 * sin(dot(c, vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0 * j);
    j *= .125;
    r.x = fract(512.0 * j);
    j *= .125;
    r.y = fract(512.0 * j);
    return r - 0.5;
}

/* skew constants for 3d simplex functions */
const float F3 = 0.3333333;
const float G3 = 0.1666667;

/* 3d simplex noise */
float simplex3d(vec3 p) {
    /* 1. find current tetrahedron T and it's four vertices */
    /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
    /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/

    /* calculate s and x */
    vec3 s = floor(p + dot(p, vec3(F3)));
    vec3 x = p - s + dot(s, vec3(G3));

    /* calculate i1 and i2 */
    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e * (1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy * (1.0 - e);

    /* x1, x2, x3 */
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0 * G3;
    vec3 x3 = x - 1.0 + 3.0 * G3;

    /* 2. find four surflets and store them in d */
    vec4 w, d;

    /* calculate surflet weights */
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);

    /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
    w = max(0.6 - w, 0.0);

    /* calculate surflet components */
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);

    /* multiply d by w^4 */
    w *= w;
    w *= w;
    d *= w;

    /* 3. return the sum of the four surflets */
    return dot(d, vec4(52.0));
}

float noise(vec3 m) {
    return 0.5333333 * simplex3d(m)
        + 0.2666667 * simplex3d(2.0 * m)
        + 0.1333333 * simplex3d(4.0 * m)
        + 0.0666667 * simplex3d(8.0 * m);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2. - 1.;

    vec2 p = fragCoord.xy / iResolution.x;
    vec3 p3 = vec3(p, iTime * 0.4);

    float intensity = noise(vec3(p3 * 12.0 + 12.0));

    float t = clamp((uv.x * -uv.x * 0.16) + 0.15, 0., 1.);
    float y = abs(intensity * -t + uv.y);

    float g = pow(y, 0.2);

    vec3 col = vec3(1.70, 1.48, 1.78);
    col = col * -g + col;
    col = col * col;
    col = col * col;

    fragColor.w = 1.;

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, col.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}

/* Origial shader and setup source

!!ARBfp1.0

OUTPUT output = result.color;
TEMP glow, turb, y, t, mid;

PARAM glowFallOff = 0.2;
PARAM color = { 1.70, 1.48, 1.78, 0 };

TEX		turb, fragment.texcoord[0], texture[0], 3D;
MAD		turb.x, turb.x, 2, -1;

MAD_SAT	t.x, fragment.texcoord[1].y, -fragment.texcoord[1].y, 0.15;

MAD		y, turb.x, -t.x, fragment.texcoord[1].x;
ABS		y, y;

POW		glow.x, y.x, glowFallOff.x;
MAD		glow, -glow.x, color, color;
MUL		glow, glow, glow;
MUL		output, glow, glow;

END
*/

/*
	float z = currTime * 0.8f;
	float y = z * 1.82f;

	glBegin(GL_TRIANGLE_STRIP);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB, -1, y - 1, z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB,  1, -0.4f);
		glVertex2f(-1,  1);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB,  1, y - 1, z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB,  1, 0.4f);
		glVertex2f( 1,  1);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB, -1, y,     z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB,  0, -0.4f);
		glVertex2f(-1,  0);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB,  1, y,     z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB,  0, 0.4f);
		glVertex2f( 1,  0);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB, -1, y - 1, z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB, -1, -0.4f);
		glVertex2f(-1, -1);
		glMultiTexCoord3fARB(GL_TEXTURE0_ARB,  1, y - 1, z);
		glMultiTexCoord2fARB(GL_TEXTURE1_ARB, -1, 0.4f);
		glVertex2f( 1, -1);
	glEnd();

*/
