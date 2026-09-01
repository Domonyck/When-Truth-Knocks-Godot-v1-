shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 20.0, 1.0) = 4.0;

void fragment() {
    // Retrieve screen dimensions in pixels
    vec2 tex_size = vec2(textureSize(screen_texture, 0));
    vec2 pixel_count = tex_size / (pixel_size * 2.0);

    // Calculate pixelated UV coordinates
    vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;

    // Sample color from the screen texture
    vec4 color = texture(screen_texture, pixelated_uv);

    COLOR = color;
}