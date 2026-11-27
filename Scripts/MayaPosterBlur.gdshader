shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius = 3.0;
uniform float dim_amount = 0.28;

void fragment() {
    vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
    vec4 col = texture(screen_texture, SCREEN_UV) * 4.0;
    col += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0));
    col += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0));
    col += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y));
    col += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y));
    col += texture(screen_texture, SCREEN_UV + px);
    col += texture(screen_texture, SCREEN_UV - px);
    col += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y));
    col += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y));
    col /= 12.0;
    col.rgb *= (1.0 - dim_amount);
    COLOR = col;
}
