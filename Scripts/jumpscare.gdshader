// Analog Horror VHS Shader Pack LITE - VHS tape effect (tracking, noise, chroma bleed)
// (c) 2026 assetsmithpixels — MIT License (see LICENSE.txt)
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
group_uniforms Chroma;
uniform float chroma_shift : hint_range(0.0, 12.0) = 2.5;   // horizontal color fringe in pixels
uniform float chroma_bleed : hint_range(0.0, 1.0) = 0.6;    // horizontal color smear
uniform float saturation : hint_range(0.0, 2.0) = 0.8;
uniform vec3 tint : source_color = vec3(1.0, 0.96, 0.9);
group_uniforms Tracking;
uniform float line_wobble : hint_range(0.0, 6.0) = 1.2;     // per-line jitter in pixels
uniform float tracking_amount : hint_range(0.0, 1.0) = 0.35;
uniform float tracking_speed : hint_range(0.0, 4.0) = 0.6;
uniform float tracking_height : hint_range(0.01, 0.4) = 0.08;
uniform float head_switch_height : hint_range(0.0, 0.15) = 0.03; // distorted band at bottom
group_uniforms Noise;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.12;
uniform float static_lines : hint_range(0.0, 1.0) = 0.25;
uniform float flicker : hint_range(0.0, 0.3) = 0.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;
	float line = floor(uv.y / px.y);
	float frame = floor(t * 30.0);

	// per-line horizontal wobble
	float off = (hash(vec2(line * 0.07, frame)) - 0.5) * line_wobble * px.x;

	// rolling tracking band
	float band_y = 1.0 - fract(t * tracking_speed * 0.15);
	float band = smoothstep(tracking_height, 0.0, abs(uv.y - band_y));
	off += band * tracking_amount * (hash(vec2(line, frame + 3.0)) - 0.3) * 40.0 * px.x;

	// head-switching noise at the bottom of the frame
	float head = smoothstep(1.0 - head_switch_height, 1.0, uv.y) * step(0.0001, head_switch_height);
	off += head * (0.5 + hash(vec2(line, frame)) * 0.5) * 30.0 * px.x;

	vec2 suv = clamp(uv + vec2(off, 0.0), vec2(0.0), vec2(1.0));
	vec3 src = texture(screen_tex, suv).rgb;

	// sharp luma, blurry shifted chroma (like composite video)
	float y = dot(src, LUMA);
	vec3 acc = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		float dx = (float(i) * chroma_bleed * 3.0 + chroma_shift) * px.x;
		acc += texture(screen_tex, clamp(suv + vec2(dx, 0.0), vec2(0.0), vec2(1.0))).rgb;
	}
	acc /= 5.0;
	vec3 col = vec3(y) + (acc - vec3(dot(acc, LUMA))) * saturation;
	// extra red/blue fringe
	col.r = mix(col.r, texture(screen_tex, suv + vec2(chroma_shift * px.x, 0.0)).r, 0.35);
	col.b = mix(col.b, texture(screen_tex, suv - vec2(chroma_shift * px.x, 0.0)).b, 0.35);

	// grain
	float n = hash(uv * vec2(1.0 / px.x, 1.0 / px.y) * 0.001 + fract(t * 7.13));
	col += (n - 0.5) * noise_amount;
	// white static streaks
	float streak = step(1.0 - static_lines * 0.015, hash(vec2(line * 0.13, frame)));
	streak *= step(0.4, hash(vec2(floor(uv.x * 40.0), line + frame)));
	col += streak * 0.6;
	// noise inside tracking / head bands
	col += (band * tracking_amount + head) * (hash(vec2(uv.x * 300.0, line + frame)) - 0.4) * 0.5;

	col *= tint;
	col *= 1.0 - flicker * hash(vec2(frame, 1.7));

	COLOR = vec4(mix(texture(screen_tex, uv).rgb, clamp(col, 0.0, 1.0), intensity), 1.0);
}
