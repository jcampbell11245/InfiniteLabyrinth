shader_type canvas_item;

// Blends a sprite towards flash_color by `flash` (0..1), keeping its alpha. Used for the
// one- or two-frame white flash when something takes a hit.

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, flash), tex.a);
}
