class_name ShopMenu
extends Control

# The merchant's shop (Merchant): a square panel in the HUD's frame style with a row of
# tabs along the top and, under the selected tab, a list of things for sale. Each row shows
# the item's icon, name, description and price in coins. Up and down pick a row, the
# previous / next item buttons (or left and right) change tab, confirm buys and back
# closes. A bought item goes into the first empty box of the item bar (Game.buy_item); a
# purchase that can't happen (too few coins, no empty box) shakes the row red and says why.
#
# The game is paused while it's open, so it runs with PROCESS_MODE_ALWAYS and real-time
# tweens. It's drawn in code on an unscaled layer, in art pixels UNIT screen pixels across,
# so the frame matches the 5x HUD while the text is rendered at full resolution.

const UNIT := 5.0 # Screen pixels per art pixel, matching HudLayer's scale
const SIZE := Vector2(140, 116) # The panel, in art pixels
const MARGIN := 6.0
const TAB_SIZE := Vector2(40, 11)
const TAB_TOP := 6.0
const LIST_TOP := 24.0
const ROW_HEIGHT := 30.0
const ROW_GAP := 3.0
const SLOT := 16.0 # The icon's box, like the item bar's
const TEXT_LEFT := 24.0 # From a row's left edge to its name and description
const HINTS_TOP := SIZE.y - 15.0
const MESSAGE_TOP := HINTS_TOP - 9.0

# Font sizes, in art pixels.
const TITLE_SIZE := 5.0
const NAME_SIZE := 5.0
const TEXT_SIZE := 4.0
const LINE_HEIGHT := 6.0 # Between description lines; the font's own spacing has them touching

# Each tab: its title and the items for sale under it.
const TABS: Array[Dictionary] = [
	{title = "Items", stock = [Items.Kind.SKELETON_KEY, Items.Kind.METAL_DETECTOR]},
]

const FONT := preload("res://assets/fonts/8-BIT WONDER.TTF")
const COIN := preload("res://assets/sprites/hud/coin.png")
const COIN_FRAME := Rect2(0, 0, 7, 7) # coin.png is a sheet of spinning frames
const PANEL_FILL := Color(0.1, 0.1, 0.12, 0.96) # Nearly opaque: it's the only thing to read
const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const DIM_TEXT := Color(0.62, 0.6, 0.66)
const TOO_DEAR := Color(1, 0.4, 0.4) # A price the player can't pay
const BOUGHT_COLOR := Color8(88, 216, 84) # The minimap's green

const FLASH_TIME := 0.25
const REFUSE_TIME := 0.3
const SHAKE_DISTANCE := 2.0 # Art pixels the refused row swings at first
const SHAKE_SWINGS := 2
const MESSAGE_TIME := 1.6 # Seconds a "can't buy" or "bought" line stays

# Placeholder (PENDING_ASSETS.md), shared with the item bar: the jammed bow's click.
const REFUSED_SOUND := preload("res://assets/sfx/clank_bad.wav")
const REFUSED_PITCH := 1.6
const REFUSED_VOLUME_DB := -8.0

signal closed

var _tab := 0
var _row := 0
var _opened_frame := -1 # The interact press that opened the shop mustn't also buy
var _flash := 0.0 # White over the row just bought from, 1 to 0
var _refused := 0.0 # How far through the refused shake, 1 to 0
var _message := ""
var _message_color := TEXT_COLOR
var _message_left := 0.0 # Real seconds the message has left
var _flash_tween: Tween
var _refused_tween: Tween
var _refused_sound: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_refused_sound = AudioStreamPlayer.new()
	_refused_sound.bus = &"SFX"
	_refused_sound.stream = REFUSED_SOUND
	_refused_sound.volume_db = REFUSED_VOLUME_DB
	add_child(_refused_sound)
	Game.coins_changed.connect(func(_coins: int) -> void: queue_redraw())

func open() -> void:
	visible = true
	get_tree().paused = true
	_opened_frame = Engine.get_process_frames()
	_row = 0
	_message = ""
	queue_redraw()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func stock() -> Array:
	return TABS[_tab].stock

func _input(event: InputEvent) -> void:
	if visible:
		InputGlyphs.note(event)

func _process(delta: float) -> void:
	if !visible:
		return
	if _message_left > 0.0:
		# delta is real time here: the tree is paused, but Engine.time_scale still applies.
		_message_left -= delta / maxf(Engine.time_scale, 0.01)
		if _message_left <= 0.0:
			_message = ""
		queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	if _pressed(["ui_cancel", "pause"]):
		close()
	elif _pressed(["up", "ui_up"]):
		_move(-1)
	elif _pressed(["down", "ui_down"]):
		_move(1)
	elif _pressed(["item_previous", "ui_left"]):
		_change_tab(-1)
	elif _pressed(["item_next", "ui_right"]):
		_change_tab(1)
	elif _pressed(["interact", "select", "ui_accept"]):
		buy_selected()

func _pressed(actions: Array[String]) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _move(step: int) -> void:
	_row = posmod(_row + step, maxi(stock().size(), 1))
	queue_redraw()

func _change_tab(step: int) -> void:
	_tab = posmod(_tab + step, TABS.size())
	_row = 0
	queue_redraw()

# Buys the selected row's item, or says why it can't.
func buy_selected() -> void:
	var kind: Items.Kind = stock()[_row]
	match Game.buy_item(kind):
		Game.Purchase.BOUGHT:
			_say("Bought", BOUGHT_COLOR)
			Juice.coin_stolen_sound() # Coins leaving the purse
			_flash_tween = _restart(_flash_tween, _set_flash, FLASH_TIME)
		Game.Purchase.TOO_POOR:
			_refuse("Not enough coins")
		Game.Purchase.BAR_FULL:
			_refuse("Your item bar is full")

func _refuse(why: String) -> void:
	_say(why, TOO_DEAR)
	Juice.play(_refused_sound, 0.06, REFUSED_PITCH)
	_refused_tween = _restart(_refused_tween, _set_refused, REFUSE_TIME)

func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color
	_message_left = MESSAGE_TIME
	queue_redraw()

# A real-time tween of `setter` from 1 to 0, replacing `old`.
func _restart(old: Tween, setter: Callable, seconds: float) -> Tween:
	if old:
		old.kill()
	var tween := create_tween().set_ignore_time_scale()
	tween.tween_method(setter, 1.0, 0.0, seconds)
	return tween

func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()

func _set_refused(value: float) -> void:
	_refused = value
	queue_redraw()

# --- Drawing (all in art pixels from the panel's top-left, scaled by UNIT) ---

func _origin() -> Vector2:
	return ((get_viewport_rect().size / UNIT - SIZE) / 2.0).floor()

func _draw() -> void:
	var o := _origin()
	HudFrame.backing(self, Rect2(o, SIZE), UNIT, PANEL_FILL)
	_draw_tabs(o)
	_draw_coins(o)
	HudFrame.fill(self, Rect2(o + Vector2(MARGIN, LIST_TOP - 4), Vector2(SIZE.x - MARGIN * 2, 1)),
		ItemBar.Minimap.UNLIT, UNIT)
	var items := stock()
	for i in items.size():
		_draw_row(o, i, items[i])
	if _message != "":
		_text(_message, o + Vector2(0, MESSAGE_TOP), TEXT_SIZE, _message_color,
			HORIZONTAL_ALIGNMENT_CENTER, SIZE.x)
	_draw_hints(o)

func _draw_tabs(o: Vector2) -> void:
	for i in TABS.size():
		var tab := Rect2(o + Vector2(MARGIN + i * (TAB_SIZE.x + 3), TAB_TOP), TAB_SIZE)
		var selected := i == _tab
		HudFrame.fill(self, tab, ItemBar.SELECTED_FILL if selected else ItemBar.SLOT_FILL, UNIT)
		HudFrame.outline(self, tab, ItemBar.SELECTED_EDGE if selected else ItemBar.Minimap.UNLIT, UNIT)
		_text(String(TABS[i].title), tab.position + Vector2(0, 3), TITLE_SIZE,
			TEXT_COLOR if selected else DIM_TEXT, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x)

# The player's coins, top right, so the prices have something to compare against.
func _draw_coins(o: Vector2) -> void:
	var right := o.x + SIZE.x - MARGIN
	var top := o.y + TAB_TOP + 2
	var text := str(Game.coins)
	var width := _text_width(text, NAME_SIZE)
	_text(text, Vector2(right - width, top), NAME_SIZE, TEXT_COLOR)
	_coin(Vector2(right - width - COIN_FRAME.size.x - 2, top - 1))

func _draw_row(o: Vector2, index: int, kind: Items.Kind) -> void:
	var row := Rect2(o + Vector2(MARGIN, LIST_TOP + index * (ROW_HEIGHT + ROW_GAP)),
		Vector2(SIZE.x - MARGIN * 2, ROW_HEIGHT))
	var selected := index == _row
	var refused := selected && _refused > 0.0
	if refused:
		row.position.x += roundf(sin((1.0 - _refused) * TAU * SHAKE_SWINGS) * SHAKE_DISTANCE * _refused)
	var edge := ItemBar.SELECTED_EDGE if selected else ItemBar.Minimap.UNLIT
	if refused:
		edge = edge.lerp(ItemBar.REFUSED_COLOR, _refused)
	HudFrame.fill(self, row, ItemBar.SELECTED_FILL if selected else ItemBar.SLOT_FILL, UNIT)
	HudFrame.outline(self, row, edge, UNIT)

	var slot := Rect2(row.position + Vector2(4, (ROW_HEIGHT - SLOT) / 2.0).floor(), Vector2(SLOT, SLOT))
	HudFrame.fill(self, slot, ItemBar.SLOT_FILL, UNIT)
	HudFrame.outline(self, slot, ItemBar.Minimap.UNLIT, UNIT)
	var icon: Texture2D = Items.ICONS[kind]
	var icon_at := (slot.get_center() - icon.get_size() / 2.0).floor()
	draw_texture_rect(icon, Rect2(icon_at * UNIT, icon.get_size() * UNIT), false)

	var info: Dictionary = Items.INFO[kind]
	var text_left := row.position.x + TEXT_LEFT
	_text(String(info.name), Vector2(text_left, row.position.y + 3), NAME_SIZE, TEXT_COLOR)
	var lines := _wrap(String(info.text), TEXT_SIZE, row.end.x - 3 - text_left)
	for i in mini(lines.size(), 3):
		_text(lines[i], Vector2(text_left, row.position.y + 11 + i * LINE_HEIGHT), TEXT_SIZE, DIM_TEXT)

	var price := Items.price(kind)
	var price_text := str(price)
	var width := _text_width(price_text, NAME_SIZE)
	var right := row.end.x - 3
	_text(price_text, Vector2(right - width, row.position.y + 3), NAME_SIZE,
		TEXT_COLOR if Game.coins >= price else TOO_DEAR)
	_coin(Vector2(right - width - COIN_FRAME.size.x - 1, row.position.y + 2))

	if selected && _flash > 0.0:
		HudFrame.fill(self, row, Color(1, 1, 1, 0.6 * _flash), UNIT)

# Confirm to buy and back to leave, as buttons for the device in use, centred at the bottom.
func _draw_hints(o: Vector2) -> void:
	var hints := [[InputGlyphs.Glyph.CONFIRM, "Buy"], [InputGlyphs.Glyph.BACK, "Close"]]
	var gap := 10.0
	var total := -gap
	for hint: Array in hints:
		total += InputGlyphs.width(hint[0]) + 2 + _text_width(hint[1], TEXT_SIZE) + gap
	var x := o.x + floorf((SIZE.x - total) / 2.0)
	var top := o.y + HINTS_TOP
	for hint: Array in hints:
		InputGlyphs.draw(self, hint[0], Vector2(x, top), UNIT)
		x += InputGlyphs.width(hint[0]) + 2
		_text(hint[1], Vector2(x, top + 2), TEXT_SIZE, DIM_TEXT)
		x += _text_width(hint[1], TEXT_SIZE) + gap

func _coin(at: Vector2) -> void:
	draw_texture_rect_region(COIN, Rect2(at.floor() * UNIT, COIN_FRAME.size * UNIT), COIN_FRAME)

# One line of text with its top-left corner at `at` (art pixels), aligned within `width`.
func _text(text: String, at: Vector2, size: float, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font_size := roundi(size * UNIT)
	var baseline := Vector2(at.x * UNIT, at.y * UNIT + FONT.get_ascent(font_size)).round()
	draw_string(FONT, baseline, text, align, width * UNIT if width > 0 else -1.0, font_size, color)

# `text` broken into lines no wider than `width` art pixels, at word boundaries.
func _wrap(text: String, size: float, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var longer := word if line == "" else line + " " + word
		if line != "" && _text_width(longer, size) > width:
			lines.append(line)
			line = word
		else:
			line = longer
	if line != "":
		lines.append(line)
	return lines

func _text_width(text: String, size: float) -> float:
	return ceilf(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * UNIT)).x / UNIT)
