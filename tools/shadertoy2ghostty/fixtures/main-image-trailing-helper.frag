void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  float pulse = helperPulse(uv);
  fragColor = vec4(vec3(pulse), 1.0);
}

float helperPulse(vec2 uv) {
  return 0.5 + 0.5 * sin(10.0 * uv.x + iTime);
}
