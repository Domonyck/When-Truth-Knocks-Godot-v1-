shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color;
uniform float brightness = 1.4;
uniform float scanlines_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_intensity = 0.4;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	
	// CRT scanline effect
	float scanline = sin(UV.y * 800.0) * 0.5 + 0.5;
	vec3 col = mix(tex.rgb, tex.rgb * scanline, scanlines_opacity);
	
	// Vignette effect
	vec2 uv_vignette = UV * (1.0 - UV.xy);
	float vig = uv_vignette.x * uv_vignette.y * 15.0;
	vig = pow(vig, vignette_intensity);
	
	ALBEDO = col * brightness * vig;
	ALPHA = tex.a; // Makes transparent parts of your image actually transparent
}