shader_type canvas_item;

// Allows reading the pixels behind this CanvasItem
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Controls how blurry the background gets
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;

void fragment() {
	// Sample the screen texture with a specific level of detail (LOD) for the blur effect
	vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	
	// Mix in the ColorRect's assigned tint color
	COLOR = color * COLOR;
}