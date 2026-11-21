class_name ItemBar
extends Node2D

# The row of consumable item boxes at the bottom of the screen: Tuning.item_slots boxes,
# one of them highlighted (Game.item_slot). The player moves the highlight with
# item_previous / item_next and uses what's in it with use_item (Player._handle_input).
# Items don't exist yet, so the boxes are empty and using one only flashes its box.
#
# Everything is drawn in code in HUD units (HudLayer is scaled 5x), centred on this node,
# and kept on whole units so the edges stay crisp pixels.

const BOX := 16 # Outer size of one box
const GAP := 3 # Between boxes
const PAD := 3 # Between the boxes and the edge of the panel behind them

const PANEL_FILL := Color(0.06, 0.05, 0.09, 0.75)
const PANEL_EDGE := Color(0.3, 0.27, 0.36)
const BOX_FILL := Color(0.13, 0.11, 0.17, 0.9)
const BOX_EDGE := Color(0.42, 0.39, 0.5)
const SELECTED_FILL := Color(0.25, 0.2, 0.13, 0.95)
const SELECTED_EDGE := Color(1.0, 0.82, 0.3)
const FLASH_COLOR := Color(1, 1, 1, 0.8)

const POP := 1.2 # Scale the highlighted box jumps to when the highlight moves onto it
const POP_TIME := 0.15
const FLASH_TIME := 0.25

var _pop := 1.0 # Current scale of the highlighted box
var _flash := 0.0 # How much white is over the used box, 0 to 1
var _flash_slot := 0
var _pop_tween: Tween
var _flash_tween: Tween

func _ready() -> void:
	Game.item_selected.connect(_on_item_selected)
	Game.item_used.connect(_on_item_used)
	Tuning.changed.connect(_on_tuning_changed)

func _on_item_selected(_slot: int) -> void:
	if _pop_tween:
		_pop_tween.kill()
	# Real time, so hit-stop and slow motion don't freeze the HUD.
	_pop_tween = create_tween().set_ignore_time_scale()
	_pop_tween.tween_method(_set_pop, POP, 1.0, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_item_used(slot: int) -> void:
	_flash_slot = slot
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_ignore_time_scale()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)

# Changing the box count from the debug menu (F2) keeps the highlight on a box that exists.
func _on_tuning_changed(key: String) -> void:
	if key == "item_slots":
		Game.cycle_item(0)
		queue_redraw()

func _set_pop(value: float) -> void:
	_pop = value
	queue_redraw()

func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()

func _draw() -> void:
	var count := maxi(Tuning.item_slots, 1)
	var width := count * BOX + (count - 1) * GAP
	var left := -floorf(width / 2.0)
	var top := -BOX / 2.0
	var panel := Rect2(left - PAD, top - PAD, width + PAD * 2, BOX + PAD * 2)
	draw_rect(panel, PANEL_FILL)
	_draw_frame(panel, PANEL_EDGE)
	for i in count:
		var box := Rect2(left + i * (BOX + GAP), top, BOX, BOX)
		var selected := i == Game.item_slot
		if selected:
			box = box.grow((BOX * (_pop - 1.0)) / 2.0)
		draw_rect(box, SELECTED_FILL if selected else BOX_FILL)
		_draw_frame(box, SELECTED_EDGE if selected else BOX_EDGE)
		if selected:
			# A second, inner ring makes the highlight read at a glance.
			_draw_frame(box.grow(-1), SELECTED_EDGE * Color(1, 1, 1, 0.45))
		if i == _flash_slot && _flash > 0.0:
			draw_rect(box, FLASH_COLOR * Color(1, 1, 1, _flash))

# A one-unit outline inside `rect`, drawn as filled strips: draw_rect's own outline is
# centred on the edge, which would put it on half units and blur it.
func _draw_frame(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	draw_rect(Rect2(p, Vector2(s.x, 1)), color)
	draw_rect(Rect2(p.x, rect.end.y - 1, s.x, 1), color)
	draw_rect(Rect2(p.x, p.y + 1, 1, s.y - 2), color)
	draw_rect(Rect2(rect.end.x - 1, p.y + 1, 1, s.y - 2), color)
