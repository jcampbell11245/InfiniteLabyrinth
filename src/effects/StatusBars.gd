class_name StatusBars
extends Node2D

# Small colour-coded bars floating over a character's head, each with a white icon on its
# left saying what it's for: cooldowns counting down, a parry streak filling up. A bar
# only shows while its value is above 0; the visible ones stack upwards from this node's
# position. Drawn in code like the other effects, in world pixels whatever the owner's
# scale. Add one as a child and give it bars with add_bar().

# PARRY on down are the player's curses from a warlock (see Curses).
enum Icon { SWORD, ROLL, ARROW, DAZE, PARRY, INVERTED, DEFENSE_DOWN, ATTACK_DOWN, SLOW, JAM, SPIN }

const BAR_SIZE := Vector2(14, 2)
const ICON_SIZE := 5.0 # Width of the icon's box, left of the bar
const ICON_GAP := 2.0
const ROW_HEIGHT := 6.0 # Pixels between stacked bars
const OUTLINE := Color(0, 0, 0, 0.75)
const EMPTY := Color(0.15, 0.15, 0.15, 0.75)
const ICON_COLOR := Color(1, 1, 1)

var _bars: Array[Dictionary] = []
var _ink := ICON_COLOR # Colour of the icon being drawn

# `value` returns how full the bar is, 0 to 1; 0 or less hides it.
func add_bar(icon: Icon, color: Color, value: Callable, icon_color := ICON_COLOR) -> void:
	_bars.append({icon = icon, color = color, value = value, icon_color = icon_color})

# How much of a running timer is left, 1 just started to 0 finished (or stopped).
static func timer_left(timer: Timer) -> float:
	if timer.is_stopped() || timer.wait_time <= 0:
		return 0.0
	return clampf(timer.time_left / timer.wait_time, 0.0, 1.0)

func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent != null && parent.scale.x != 0 && parent.scale.y != 0:
		scale = Vector2.ONE / parent.scale # Same size on every character
	queue_redraw()

func _draw() -> void:
	var left := -(ICON_SIZE + ICON_GAP + BAR_SIZE.x) / 2
	var y := 0.0
	for bar in _bars:
		var amount: float = bar.value.call()
		if amount <= 0:
			continue
		var bar_pos := Vector2(left + ICON_SIZE + ICON_GAP, y - BAR_SIZE.y / 2)
		draw_rect(Rect2(bar_pos - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), OUTLINE)
		draw_rect(Rect2(bar_pos, BAR_SIZE), EMPTY)
		draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * minf(amount, 1.0), BAR_SIZE.y)), bar.color)
		_ink = bar.icon_color
		_draw_icon(bar.icon, Vector2(left + ICON_SIZE / 2, y))
		y -= ROW_HEIGHT

func _draw_icon(icon: Icon, at: Vector2) -> void:
	match icon:
		Icon.SWORD: # Blade pointing up and right, with a crossguard
			draw_line(at + Vector2(-1.5, 1.5), at + Vector2(2.5, -2.5), _ink, 1.0)
			draw_line(at + Vector2(-2.5, 0.5), at + Vector2(-0.5, 2.5), _ink, 1.0)
			draw_line(at + Vector2(-1.5, 1.5), at + Vector2(-2.5, 2.5), _ink, 1.0)
		Icon.ROLL: # A circling arrow
			draw_arc(at, 2.0, PI * 0.1, PI * 1.6, 8, _ink, 1.0)
			var tip := at + Vector2.from_angle(PI * 0.1) * 2.0
			draw_line(tip, tip + Vector2(-1.5, -0.5), _ink, 1.0)
			draw_line(tip, tip + Vector2(0.5, -1.5), _ink, 1.0)
		Icon.ARROW: # Shaft, head on the right, fletching on the left
			draw_line(at + Vector2(-2.5, 0), at + Vector2(2.5, 0), _ink, 1.0)
			draw_line(at + Vector2(2.5, 0), at + Vector2(1, -1.5), _ink, 1.0)
			draw_line(at + Vector2(2.5, 0), at + Vector2(1, 1.5), _ink, 1.0)
			draw_line(at + Vector2(-2.5, 0), at + Vector2(-3.5, -1.2), _ink, 1.0)
			draw_line(at + Vector2(-2.5, 0), at + Vector2(-3.5, 1.2), _ink, 1.0)
		Icon.DAZE: # A four-pointed star, like the dizzy stars
			var points := PackedVector2Array()
			for j in 4:
				points.append(at + Vector2.from_angle(j * PI / 2 - PI / 2) * 2.8)
				points.append(at + Vector2.from_angle(j * PI / 2 - PI / 4) * 0.9)
			draw_colored_polygon(points, _ink)
		Icon.PARRY: # A small shield
			var shield := PackedVector2Array([
				at + Vector2(-2.2, -2.5), at + Vector2(2.2, -2.5), at + Vector2(2.2, 0),
				at + Vector2(0, 2.8), at + Vector2(-2.2, 0), at + Vector2(-2.2, -2.5)])
			draw_polyline(shield, _ink, 1.0)
		Icon.INVERTED: # Two arrows pointing opposite ways
			draw_line(at + Vector2(-2.5, -1.2), at + Vector2(2.5, -1.2), _ink, 1.0)
			draw_line(at + Vector2(2.5, -1.2), at + Vector2(1.2, -2.5), _ink, 1.0)
			draw_line(at + Vector2(-2.5, 1.2), at + Vector2(2.5, 1.2), _ink, 1.0)
			draw_line(at + Vector2(-2.5, 1.2), at + Vector2(-1.2, 2.5), _ink, 1.0)
		Icon.DEFENSE_DOWN: # The parry shield, cracked down the middle
			var shield := PackedVector2Array([
				at + Vector2(-2.2, -2.5), at + Vector2(2.2, -2.5), at + Vector2(2.2, 0),
				at + Vector2(0, 2.8), at + Vector2(-2.2, 0), at + Vector2(-2.2, -2.5)])
			draw_polyline(shield, _ink, 1.0)
			draw_polyline(PackedVector2Array([at + Vector2(0.3, -2.5), at + Vector2(-0.6, -0.6),
				at + Vector2(0.6, 0.4), at + Vector2(-0.2, 2.2)]), _ink, 1.0)
		Icon.ATTACK_DOWN: # The sword icon turned point-down
			draw_line(at + Vector2(1.5, -1.5), at + Vector2(-2.5, 2.5), _ink, 1.0)
			draw_line(at + Vector2(2.5, -0.5), at + Vector2(0.5, -2.5), _ink, 1.0)
			draw_line(at + Vector2(1.5, -1.5), at + Vector2(2.5, -2.5), _ink, 1.0)
		Icon.SLOW: # A snail: round shell, body trailing off to the left
			draw_arc(at + Vector2(0.6, -0.4), 1.9, 0, TAU, 10, _ink, 1.0)
			draw_line(at + Vector2(-2.8, 2.2), at + Vector2(2.8, 2.2), _ink, 1.0)
			draw_line(at + Vector2(-2.8, 2.2), at + Vector2(-2.8, 0.6), _ink, 1.0)
		Icon.JAM: # The arrow icon, crossed out
			draw_line(at + Vector2(-2.5, 0), at + Vector2(2.5, 0), _ink, 1.0)
			draw_line(at + Vector2(2.5, 0), at + Vector2(1, -1.5), _ink, 1.0)
			draw_line(at + Vector2(2.5, 0), at + Vector2(1, 1.5), _ink, 1.0)
			draw_line(at + Vector2(-2.2, -2.5), at + Vector2(2.2, 2.5), Color(1, 0.3, 0.3), 1.0)
		Icon.SPIN: # A blade with a sweep curling round behind it
			draw_line(at, at + Vector2(2.5, -2.5), _ink, 1.0)
			draw_arc(at, 2.6, PI * 0.25, PI * 1.6, 8, _ink, 1.0)
