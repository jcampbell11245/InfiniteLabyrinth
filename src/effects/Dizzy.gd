extends Node2D

# Little stars circling over a head, shown while someone is stunned or dazed by a
# parry. Drawn in code like the other effects. Made by Juice.dizzy(); whoever owns it
# frees it when the stun or daze ends.

const STAR_COUNT := 3
const ORBIT := Vector2(8, 3) # Radii of the elliptical orbit, in pixels
const SPIN_SPEED := 5.0 # Radians per second
const STAR_SIZE := 2.5 # Pixels from centre to point
const STAR_WIDTH := 0.8

var color := Color(1, 0.95, 0.7)
var _angle := 0.0

func _process(delta: float) -> void:
	_angle += SPIN_SPEED * delta
	queue_redraw()

func _draw() -> void:
	for i in STAR_COUNT:
		var a := _angle + TAU * i / STAR_COUNT
		var at := Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y)
		# Stars passing behind the head are dimmer.
		var star_color := Color(color, 1.0 if sin(a) > 0 else 0.55)
		var points := PackedVector2Array()
		for j in 4:
			points.append(at + Vector2.from_angle(j * PI / 2) * STAR_SIZE)
			points.append(at + Vector2.from_angle(j * PI / 2 + PI / 4) * STAR_WIDTH)
		draw_colored_polygon(points, star_color)
