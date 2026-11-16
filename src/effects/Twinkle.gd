extends Node2D

# A four-pointed star glint that pops in, spins a quarter turn and shrinks away, then
# frees itself. Drawn in code like the other effects, so it needs no sprite. Made by
# Juice.twinkle().

const LIFETIME := 0.3 # Seconds
const POP_IN := 0.25 # Fraction of LIFETIME spent growing; the rest is shrinking
const POINT_LENGTH := 6.0 # Pixels from the centre to the tip of each long point
const POINT_WIDTH := 1.5 # Pixels from the centre to the side of each point
const DIAGONAL_SCALE := 0.45 # Size of the short diagonal points against the long ones

var color := Color(1, 0.95, 0.7)

func _ready() -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, LIFETIME * POP_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, LIFETIME * (1.0 - POP_IN)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "rotation", PI / 2, LIFETIME * (1.0 - POP_IN))
	tween.finished.connect(queue_free)

func _draw() -> void:
	_draw_star(POINT_LENGTH * DIAGONAL_SCALE, POINT_WIDTH * DIAGONAL_SCALE, PI / 4,
		Color(color, 0.7))
	_draw_star(POINT_LENGTH, POINT_WIDTH, 0.0, color)
	draw_circle(Vector2.ZERO, POINT_WIDTH, Color.WHITE)

# Four thin points (up, right, down, left), turned by `angle`.
func _draw_star(length: float, width: float, angle: float, star_color: Color) -> void:
	var points := PackedVector2Array()
	for i in 4:
		var tip := Vector2.from_angle(angle + i * PI / 2) * length
		var side := Vector2.from_angle(angle + i * PI / 2 + PI / 4) * width
		points.append(tip)
		points.append(side)
	draw_colored_polygon(points, star_color)
