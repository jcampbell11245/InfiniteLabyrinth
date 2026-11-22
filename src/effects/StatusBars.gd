class_name StatusBars
extends Node2D

# Small colour-coded bars floating over a character's head, each with an icon on its left
# saying what it's for: cooldowns counting down, a parry streak filling up, curses running
# out. A bar only shows while its value is above 0; the visible ones stack upwards from
# this node's position. Drawn in code in world pixels whatever the owner's scale, with the
# icons cut from status_icons.png. Add one as a child and give it bars with add_bar().

# INVERTED to JAM are the player's curses from a warlock (see Curses). SLOW is also a slow
# tile's; FAST (a speed tile) and PASTE (caught in thermal paste) are special tiles'.
# ATTACK_UP and DEFENSE_UP are a server's boosts on an enemy (see ServerBuff); its speed
# boost shows FAST.
enum Icon { SWORD, ROLL, ARROW, DAZE, PARRY, INVERTED, DEFENSE_DOWN, ATTACK_DOWN, SLOW, JAM, SPIN, FAST, PASTE,
	ATTACK_UP, DEFENSE_UP }

# status_icons.png: a row of 18x18 icons. Which cell each Icon is, left to right from 0.
# Cell 1 is the enemy's strike twinkle (see Twinkle), not a bar icon.
const ICON_SHEET := preload("res://assets/sprites/hud/status_icons.png")
const ICON_CELL := 18
const SHEET_CELLS := {
	Icon.SPIN: 0, Icon.SWORD: 2, Icon.ARROW: 3, Icon.DAZE: 4, Icon.ROLL: 5,
	Icon.INVERTED: 6, Icon.PARRY: 7, Icon.DEFENSE_DOWN: 8, Icon.ATTACK_DOWN: 9,
	Icon.SLOW: 10, Icon.JAM: 11, Icon.FAST: 12, Icon.PASTE: 13, Icon.ATTACK_UP: 14, Icon.DEFENSE_UP: 15,
}
# World pixels per icon pixel. Rooms are seen at 2.5x zoom, so 0.4 puts one icon pixel on
# one screen pixel at 1080p and keeps them crisp.
const ICON_SCALE := 0.4

const BAR_SIZE := Vector2(14, 2)
const ICON_SIZE := ICON_CELL * ICON_SCALE # Width of the icon, left of the bar
const ICON_GAP := 1.5
const ROW_HEIGHT := 8.0 # Pixels between stacked bars
const OUTLINE := Color(0, 0, 0, 0.75)
const EMPTY := Color(0.15, 0.15, 0.15, 0.75)

var _bars: Array[Dictionary] = []

# `value` returns how full the bar is, 0 to 1; 0 or less hides it.
func add_bar(icon: Icon, color: Color, value: Callable) -> void:
	_bars.append({icon = icon, color = color, value = value})

# How much of a running timer is left, 1 just started to 0 finished (or stopped).
static func timer_left(timer: Timer) -> float:
	if timer.is_stopped() || timer.wait_time <= 0:
		return 0.0
	return clampf(timer.time_left / timer.wait_time, 0.0, 1.0)

# The sheet's region for cell `index`.
static func cell_region(index: int) -> Rect2:
	return Rect2(index * ICON_CELL, 0, ICON_CELL, ICON_CELL)

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
		var icon_rect := Rect2(Vector2(left, y - ICON_SIZE / 2), Vector2.ONE * ICON_SIZE)
		draw_texture_rect_region(ICON_SHEET, icon_rect, cell_region(SHEET_CELLS[bar.icon]))
		y -= ROW_HEIGHT
