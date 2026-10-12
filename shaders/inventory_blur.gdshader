shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float blur_radius = 1.5;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float darken = 0.0;

// Dense 15-tap Gaussian. Small sample spacing blends thin text strokes smoothly;
// the inventory runs this kernel horizontally, refreshes the back buffer, then
// runs it vertically to avoid the separated silhouettes from the old wide taps.
void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_radius * direction;
	vec2 uv = SCREEN_UV;
	vec4 blurred = vec4(0.0);
	blurred += texture(screen_texture, uv + step_uv * -7.0) * (1.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -6.0) * (2.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -5.0) * (4.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -4.0) * (7.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -3.0) * (11.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -2.0) * (15.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * -1.0) * (18.0 / 136.0);
	blurred += texture(screen_texture, uv) * (20.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 1.0) * (18.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 2.0) * (15.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 3.0) * (11.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 4.0) * (7.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 5.0) * (4.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 6.0) * (2.0 / 136.0);
	blurred += texture(screen_texture, uv + step_uv * 7.0) * (1.0 / 136.0);
	vec3 tinted = blurred.rgb * tint;
	tinted = mix(tinted, vec3(0.018, 0.024, 0.060), darken);
	COLOR = vec4(tinted, 1.0);
}
