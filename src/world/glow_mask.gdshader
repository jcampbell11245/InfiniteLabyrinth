shader_type canvas_item;
render_mode unshaded;

// Keeps only a sprite's bright blue pixels (a knight's visor, horns and sword) and drops
// the rest, for GlowMask: drawn over the darkness, those pixels keep their full colour, so
// they read as glowing. Darker blues (the shield, shading) and greys are left out.

uniform float min_value = 0.85; // Brightness of the brightest channel a glowing pixel needs
uniform float min_saturation = 0.3; // How far from grey it must be

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float high = max(c.r, max(c.g, c.b));
	float low = min(c.r, min(c.g, c.b));
	float saturation = high > 0.0 ? (high - low) / high : 0.0;
	bool blue = c.b >= c.g && c.g > c.r;
	if (c.a < 0.5 || !blue || high < min_value || saturation < min_saturation) {
		discard;
	}
	COLOR = vec4(c.rgb, COLOR.a);
}
