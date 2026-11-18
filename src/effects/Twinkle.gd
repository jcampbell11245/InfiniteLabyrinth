extends Node2D

# The "about to strike" glint (cell 1 of status_icons.png) that pops in, spins a quarter
# turn and shrinks away, then frees itself. Made by Juice.twinkle(). Normally drawn as the
# art is; with `solid` set (a knight's unparryable swing) it's that colour all over, its
# shape kept, through the flash shader.

const LIFETIME := 0.3 # Seconds
const POP_IN := 0.25 # Fraction of LIFETIME spent growing; the rest is shrinking
const SIZE := 12.0 # Pixels across at full size, in the owner's units
const SHEET_CELL := 1 # Its cell in StatusBars.ICON_SHEET

var solid := Color(0, 0, 0, 0) # Transparent: the art's own colours

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if solid.a > 0:
		Juice.add_flash(self)
		var flash := material as ShaderMaterial
		flash.set_shader_parameter("flash_color", solid)
		flash.set_shader_parameter("flash", 1.0)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, LIFETIME * POP_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, LIFETIME * (1.0 - POP_IN)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "rotation", PI / 2, LIFETIME * (1.0 - POP_IN))
	tween.finished.connect(queue_free)

func _draw() -> void:
	draw_texture_rect_region(StatusBars.ICON_SHEET, Rect2(Vector2.ONE * -SIZE / 2, Vector2.ONE * SIZE),
		StatusBars.cell_region(SHEET_CELL))
