class_name ItemBar
extends Node2D

# The row of consumable item boxes in the bottom-left corner: Tuning.item_slots boxes, one
# of them highlighted (Game.item_slot), each showing the icon of the item in it
# (Game.items, see Items). The player moves the highlight with item_previous / item_next
# and uses what's in it with use_item (Player._handle_input). A used item flashes its box
# white as it goes; one that can't be used, or an empty box, shakes the box red with a dull
# click instead.
#
# It is styled as a partner to the minimap in the opposite corner and borrows its colours
# and frame: a translucent dark backing with a grey rim, a black outer line and notched
# corners, the same margin from the screen's edges, and the unselected boxes outlined in
# the grey of an unvisited room's dot. The highlighted box has a plain white outline.
#
# Above the bar, a row of small icons shows the items still working (ItemEffects): each timed
# boost with a line under it that shrinks as its time runs out, and a charged mace until
# its swing.
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
const SELECTED_EDGE := Color.WHITE
const SELECTED_FILL := Color(1, 1, 1, 0.12) # A faint lift behind the white outline
const FLASH_COLOR := Color(1, 1, 1, 0.8)
const REFUSED_COLOR := Color(1, 0.25, 0.25)
const CHOOSING_EDGE := Minimap.KEY_ROOM # The highlight while the shop asks which box to replace
const CHOOSING_BLINK := 0.3 # Seconds the choosing highlight spends bright, then dim

const POP := 1.2 # Scale the highlighted box jumps to when the highlight moves onto it
const POP_TIME := 0.15
const FLASH_TIME := 0.25
const SHAKE_DISTANCE := 2.0 # HUD units the refused box swings each way at first
const SHAKE_SWINGS := 2 # Full side-to-side swings while it shakes
const REFUSE_TIME := 0.3

const EFFECT_ICON := 12 # Item icons are 12 units square
const EFFECT_GAP := 2 # Between the effect icons, and between their row and the bar
const TIME_LINE := Color(1, 1, 1, 0.85) # The line under a timed effect showing its time left
const TIMED_EFFECTS: Array[Items.Kind] = [Items.Kind.LUCKY_CAT, Items.Kind.RAM_STICK, Items.Kind.BROKEN_WATCH]

# Placeholder (PENDING_ASSETS.md): the jammed bow's click, borrowed until the bar has its own.
const REFUSED_SOUND := preload("res://assets/sfx/clank_bad.wav")
const REFUSED_PITCH := 1.6
const REFUSED_VOLUME_DB := -8.0
# The key unlocking a room plays the room's own unlock sound; the detector gets a ding.
const DETECTOR_SOUND := preload("res://assets/sfx/twinkle.wav")

var _pop := 1.0 # Current scale of the highlighted box
var _flash := 0.0 # How much white is over the used box, 0 to 1
var _flash_slot := 0
var _refused := 0.0 # How far through the refused shake, 1 to 0
var _refused_slot := 0
var _pop_tween: Tween
var _flash_tween: Tween
var _refused_tween: Tween
var _refused_sound: AudioStreamPlayer
var _detector_sound: AudioStreamPlayer
var _effects_shown := false # Effect icons were drawn last frame, so their going needs a redraw

func _ready() -> void:
	Game.item_selected.connect(_on_item_selected)
	Game.item_used.connect(_on_item_used)
	Game.item_refused.connect(_on_item_refused)
	Game.items_changed.connect(queue_redraw)
	Game.choosing_item_changed.connect(func(_choosing: bool) -> void: queue_redraw())
	# The shop pauses the game while it asks for a box, and the highlight has to move then.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Tuning.changed.connect(_on_tuning_changed)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refused_sound = _add_sound(REFUSED_SOUND, REFUSED_VOLUME_DB)
	_detector_sound = _add_sound(DETECTOR_SOUND, 0.0)
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

func _add_sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"SFX"
	sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	return sound

func _on_item_used(slot: int, kind: Items.Kind) -> void:
	_flash_slot = slot
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween().set_ignore_time_scale()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)
	if kind == Items.Kind.METAL_DETECTOR:
		Juice.play(_detector_sound, 0.05)

func _on_item_refused(slot: int) -> void:
	_refused_slot = slot
	if _refused_tween:
		_refused_tween.kill()
	_refused_tween = create_tween().set_ignore_time_scale()
	_refused_tween.tween_method(_set_refused, 1.0, 0.0, REFUSE_TIME)
	Juice.play(_refused_sound, 0.06, REFUSED_PITCH)

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

func _set_refused(value: float) -> void:
	_refused = value
	queue_redraw()

# Sideways offset of the refused box: a swing that dies away, on whole units.
func _refused_offset() -> float:
	return roundf(sin((1.0 - _refused) * TAU * SHAKE_SWINGS) * SHAKE_DISTANCE * _refused)

func _slot_count() -> int:
	return maxi(Tuning.item_slots, 1)

# The backing including its grey rim; the black outer line sits one unit outside it.
func _backing_size() -> Vector2:
	var count := _slot_count()
	var inset := PAD + 1
	return Vector2(count * BOX + (count - 1) * GAP + inset * 2, BOX + inset * 2)

func _draw() -> void:
	HudFrame.backing(self, Rect2(Vector2.ZERO, _backing_size()))
	var inset := PAD + 1
	for i in _slot_count():
		var box := Rect2(inset + i * (BOX + GAP), inset, BOX, BOX)
		var selected := i == Game.item_slot
		if selected:
			# Whole units only, so the pop doesn't blur the edges.
			box = box.grow(roundf(BOX * (_pop - 1.0) / 2.0))
		var refused := i == _refused_slot && _refused > 0.0
		if refused:
			box.position.x += _refused_offset()
		draw_rect(box, SLOT_FILL)
		var edge := SELECTED_EDGE if selected else Minimap.UNLIT
		if selected && Game.choosing_item:
			edge = CHOOSING_EDGE if _blink_on() else CHOOSING_EDGE.darkened(0.45)
		if selected:
			draw_rect(box.grow(-1), SELECTED_FILL)
		if refused:
			edge = edge.lerp(REFUSED_COLOR, _refused)
		HudFrame.outline(self, box, edge)
		_draw_icon(Game.item_in(i), box)
		if i == _flash_slot && _flash > 0.0:
			draw_rect(box, FLASH_COLOR * Color(1, 1, 1, _flash))
	_draw_effects()

# The items working now, in a row just above the bar's outer line, left-aligned with it.
func _draw_effects() -> void:
	var kinds := _working_items()
	if kinds.is_empty():
		return
	var effects := ItemEffects.current()
	var step := EFFECT_ICON + EFFECT_GAP
	var height := EFFECT_ICON + 2 # The icon and its time line under it
	var inset := PAD + 1
	var row := Rect2(0, -EFFECT_GAP - 2 - height - inset * 2,
		kinds.size() * step - EFFECT_GAP + inset * 2, height + inset * 2)
	HudFrame.backing(self, row)
	for i in kinds.size():
		var kind := kinds[i]
		var at := row.position + Vector2(inset + i * step, inset)
		draw_texture(Items.ICONS[kind], at)
		if kind in TIMED_EFFECTS:
			var left := effects.time_left(kind)
			var share := left / maxf(Items.duration(kind), left)
			var width := ceilf(EFFECT_ICON * share)
			draw_rect(Rect2(at + Vector2(0, EFFECT_ICON + 1), Vector2(width, 1)), TIME_LINE)

# The items working now: the timed boosts that are on, then a charged mace.
func _working_items() -> Array[Items.Kind]:
	var kinds: Array[Items.Kind] = []
	var effects := ItemEffects.current()
	if effects == null:
		return kinds
	for kind in TIMED_EFFECTS:
		if effects.is_active(kind):
			kinds.append(kind)
	if effects.mace_charged:
		kinds.append(Items.Kind.PREOWNED_MACE)
	return kinds

func _process(_delta: float) -> void:
	var effects_on := !_working_items().is_empty()
	if Game.choosing_item || effects_on || _effects_shown:
		queue_redraw() # The blink, or the effects' time lines
	_effects_shown = effects_on

func _blink_on() -> bool:
	return int(Time.get_ticks_msec() / (CHOOSING_BLINK * 1000.0)) % 2 == 0

# The item's icon centred in `box`, on whole units.
func _draw_icon(kind: Items.Kind, box: Rect2) -> void:
	var icon: Texture2D = Items.ICONS.get(kind)
	if icon == null:
		return
	var at := (box.get_center() - icon.get_size() / 2.0).floor()
	draw_texture(icon, at)
