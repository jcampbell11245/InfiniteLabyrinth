shader_type canvas_item;
render_mode unshaded;

// Multiplies everything drawn under it by the light map (CaveLighting): TEXTURE is the
// low-resolution light map, one texel per world pixel and sampled nearest, so light and
// shadow edges step in whole game pixels like the art. The map is stored at half
// brightness so lights can push a pixel above its unlit colour: 0.5 leaves it as drawn.

uniform sampler2D screen : hint_screen_texture, filter_nearest;

void fragment() {
	vec3 scene = texture(screen, SCREEN_UV).rgb;
	vec3 light = texture(TEXTURE, UV).rgb * 2.0;
	COLOR = vec4(scene * light, 1.0);
}
