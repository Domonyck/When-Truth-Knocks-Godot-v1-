shader_type canvas_item;

uniform float threshold = 0.1;
uniform float alpha = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	if (color.r < threshold && color.g < threshold && color.b < threshold) {
		color.a = 0.0;
	} else {
		color.a = alpha;
	}
	
	COLOR = color;

}
