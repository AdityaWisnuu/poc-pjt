#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform float uEnergy;
uniform float uSuccess;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 4; i++) {
    value += amplitude * noise(p);
    p = p * 2.02 + vec2(1.7, 9.2);
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = vec2(uv.x * (uSize.x / uSize.y) * 1.7, uv.y * 1.7);
  float t = uTime * (0.07 + 0.2 * uEnergy);

  vec2 warp = vec2(fbm(p + vec2(t, -t * 0.6)), fbm(p + vec2(-t * 0.8, t) + 4.1));
  float field = fbm(p + 1.9 * warp + vec2(t * 0.35, 0.0));
  float ribbon = smoothstep(0.34, 0.76, field);

  vec3 ink = vec3(0.027, 0.031, 0.047);
  vec3 cobalt = vec3(0.10, 0.25, 0.98);
  vec3 mint = vec3(0.13, 0.93, 0.70);
  vec3 coral = vec3(1.00, 0.40, 0.27);

  vec3 color = mix(ink, cobalt, ribbon);
  color = mix(color, mint, smoothstep(0.46, 0.86, warp.x) * ribbon * 0.86);
  color = mix(color, coral, smoothstep(0.54, 0.84, warp.y) * ribbon * 0.62);
  color = mix(color, mix(mint, vec3(0.92, 1.0, 0.96), ribbon * 0.45), uSuccess * (0.35 + 0.65 * ribbon));

  float fade = smoothstep(1.0, 0.16, uv.y);
  float intensity = mix(0.72, 1.0, uEnergy);
  color = mix(ink, color, clamp(fade * intensity + uSuccess * 0.3, 0.0, 1.0));

  float grain = (hash(uv * uSize + fract(uTime)) - 0.5) * 0.028;
  fragColor = vec4(color + grain, 1.0);
}
