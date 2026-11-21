class_name ItemBar
extends Node2D

# The row of consumable item boxes in the bottom-left corner: Tuning.item_slots boxes, one
# of them highlighted (Game.item_slot). The player moves the highlight with item_previous /
# item_next and uses what's in it with use_item (Player._handle_input). Items don't exist
# yet, so the boxes are empty and using one only flashes its box.
#
# It is styled as a partner to the minimap in the opposite corner and borrows its colours
# and frame: a translucent dark backing with a grey rim, a black outer line and notched
# corners, the same margin from the screen's edges, and the minimap's red "you are here"
# outline round the highlighted box, with the same white shine on its top-left pixel.
#
# Everything is drawn in code in HUD units (HudLayer is scaled 5x, so one unit is one of the
# minimap's art pixels) and kept on whole units so the edges stay crisp pixels. The node
# places itself against the bottom-left of the screen, which is lower on screens taller
# than 16:9 (stretch aspect "expand"), so its position in the scene is only a starting point.

const Minimap := preload("res://src/ui/hud/Minimap.gd")

const BOX := 16 # Outer size of one box
const GAP := 2 # Between boxes, like the gap between the minimap's dots
const PAD := 2 # Backing between the boxes and the grey rim, as on the minimap
# The minimap's margin from the screen's corner, in HUD units.
const MARGIN := Minimap.SCREEN_MARGIN / Minimap.PIXEL

const SLOT_FILL := Color(0, 0, 0, 0.35) # Sunk a little darker than the backing
const SELECTED_FILL := Color(Minimap.CURRENT_OUTLINE, 0.18)
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
	get_viewport().size_changed.connect(_place)
	_place()

# Puts the bar's top-left corner where its outer line clears the bottom-left corner of the
# screen by the minimap's margin, on whole HUD units. The origin is the backing's top-left.
func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	var to_parent := (get_parent() as CanvasItem).get_global_transform_with_canvas().affine_inverse()
	var bottom_left := to_parent * Vector2(0, screen.y)
	var height := _backing_size().y
	position = Vector2(roundf(bottom_left.x) + MARGIN.x + 1,
		floorf(bottom_left.y) - MARGIN.y - 1 - height)

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

func _slot_count() -> int:
	return maxi(Tuning.item_slots, 1)

# The backing including its grey rim; the black outer line sits one unit outside it.
func _backing_size() -> Vector2:
	var count := _slot_count()
	var inset := PAD + 1
	return Vector2(count * BOX + (count - 1) * GAP + inset * 2, BOX + inset * 2)

func _draw() -> void:
	_draw_backing(Rect2(Vector2.ZERO, _backing_size()))
	var inset := PAD + 1
	for i in _slot_count():
		var box := Rect2(inset + i * (BOX + GAP), inset, BOX, BOX)
		var selected := i == Game.item_slot
		if selected:
			# Whole units only, so the pop doesn't blur the edges.
			box = box.grow(roundf(BOX * (_pop - 1.0) / 2.0))
		draw_rect(box, SLOT_FILL)
		if selected:
			draw_rect(box.grow(-1), SELECTED_FILL)
			_draw_frame(box, Minimap.CURRENT_OUTLINE)
			draw_rect(Rect2(box.position, Vector2.ONE),
				Minimap.CURRENT_OUTLINE.lerp(Color.WHITE, Minimap.SHINE))
		else:
			_draw_frame(box, Minimap.UNLIT)
		if i == _flash_slot && _flash > 0.0:
			draw_rect(box, FLASH_COLOR * Color(1, 1, 1, _flash))

# The minimap's frame round a rectangle: translucent backing, a grey rim with its corner
# pixels notched off, and a black line outside that follows the notches round.
func _draw_backing(rect: Rect2) -> void:
	var p := rect.position
	var e := rect.end
	var w := rect.size.x
	var h := rect.size.y
	draw_rect(rect.grow(-1), Minimap.BACKING)
	for strip: Rect2 in [Rect2(p.x + 1, p.y, w - 2, 1), Rect2(p.x + 1, e.y - 1, w - 2, 1),
			Rect2(p.x, p.y + 1, 1, h - 2), Rect2(e.x - 1, p.y + 1, 1, h - 2)]:
		draw_rect(strip, Minimap.BORDER)
	for strip: Rect2 in [Rect2(p.x, p.y - 1, w, 1), Rect2(p.x, e.y, w, 1),
			Rect2(p.x - 1, p.y, 1, h), Rect2(e.x, p.y, 1, h)]:
		draw_rect(strip, Minimap.OUTER)
	for corner: Vector2 in [p, Vector2(e.x - 1, p.y), Vector2(p.x, e.y - 1), e - Vector2.ONE]:
		draw_rect(Rect2(corner, Vector2.ONE), Minimap.OUTER)

# A one-unit outline inside `rect`, drawn as filled strips: draw_rect's own outline is
# centred on the edge, which would put it on half units and blur it.
func _draw_frame(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	draw_rect(Rect2(p, Vector2(s.x, 1)), color)
	draw_rect(Rect2(p.x, rect.end.y - 1, s.x, 1), color)
	draw_rect(Rect2(p.x, p.y + 1, 1, s.y - 2), color)
	draw_rect(Rect2(rect.end.x - 1, p.y + 1, 1, s.y - 2), color)
