shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur_radius = 20.0;
uniform float overlay_alpha = 0.88;
uniform vec3 tint = vec3(0.62, 0.63, 0.80);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.20;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)) * 0.10;
	color += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)) * 0.10;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)) * 0.10;
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)) * 0.10;
	color += texture(screen_texture, SCREEN_UV + px) * 0.10;
	color += texture(screen_texture, SCREEN_UV - px) * 0.10;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)) * 0.10;
	color += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)) * 0.10;
	color.rgb *= tint;
	color.rgb = mix(color.rgb, vec3(0.025, 0.030, 0.070), 0.38);
	color.a = overlay_alpha;
	COLOR = color;
}
