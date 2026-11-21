shader_type canvas_item;

// The plain rectangle the light map is made of (CaveLighting). Its colour is the cave's
// ambient light; Godot normally scales a light by the colour of what it lands on, which on
// this dark base would leave lights barely visible, so each light adds its own full colour
// instead.

void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a);
}
