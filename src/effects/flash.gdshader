shader_type canvas_item;

// Blends a sprite towards flash_color by `flash` (0..1), keeping its alpha. Used for the
// one- or two-frame white flash when something takes a hit. `grey` (0..1) drains the
// colour and dims it first, for someone who can't act (a dazed player).

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(tex.rgb, vec3(luma * 0.75), grey);
	COLOR = vec4(mix(rgb, flash_color.rgb, flash), tex.a);
}
