shader_type canvas_item;

// Darkens everything but a circle (see Spotlight.gd). Sizes are in the rect's pixels; the
// edge is stepped on a grid of `pixel` so it matches the chunky art.
uniform vec2 rect_size = vec2(1.0);
uniform vec2 centre = vec2(0.0);
uniform float radius = 40.0;
uniform float pixel = 5.0;
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 0.75);

void fragment() {
	vec2 at = floor(UV * rect_size / pixel) * pixel + pixel * 0.5;
	COLOR = distance(at, centre) > radius ? shade : vec4(0.0);
}
