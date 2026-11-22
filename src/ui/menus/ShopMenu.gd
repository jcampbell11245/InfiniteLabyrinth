class_name ShopMenu
extends Control

# The merchant's shop (Merchant): a square panel in the HUD's frame style with a row of
# tabs along the top and, under the selected tab, a list of things for sale. Each row shows
# an icon, name, a one-line description and price in coins; the list scrolls when there
# are more than VISIBLE_ROWS. Up and down pick a row, the previous / next item buttons (or
# left and right) change tab, confirm buys and back closes. With too few coins the row
# shakes red and says so.
#
# The Upgrades tab (first) sells the lasting upgrades (Upgrades). A row names the level it
# sells, "Time Lv. 2" and so on (just "Time" for the first), and its price says "Max" once
# every level is bought. The Items tab sells
# consumables, which go into the first empty box of the item bar (Game.buy_item).
#
# Buying with every box full offers a swap instead: the shop asks the player to choose a
# box on the HUD's item bar (left and right, or the previous / next item buttons, move its
# highlight), and confirm throws that box's item away and puts the new one in its place
# (Game.replace_item). A box already holding the same item can't be chosen. Back cancels
# the swap without closing the shop.
#
# Buying is guarded against accidental double purchases: the confirm button has to be let
# go after opening the shop and after each purchase, and a purchase can't follow another
# within Tuning.shop_buy_cooldown seconds.
#
# Opening, the panel rises a little into place from below and fades in (OPEN_RISE).
#
# The game is paused while it's open, so it runs with PROCESS_MODE_ALWAYS and real-time
# tweens. It's drawn in code on an unscaled layer, in art pixels UNIT screen pixels across,
# so the frame matches the 5x HUD while the text is rendered at full resolution.

const UNIT := 5.0 # Screen pixels per art pixel, matching HudLayer's scale
const SIZE := Vector2(180, 160) # The panel, in art pixels
const MARGIN := 6.0
const TAB_HEIGHT := 11.0
const TAB_PADDING := 5.0 # Each side of a tab's title
const TAB_GAP := 3.0
const TAB_TOP := 6.0
const LIST_TOP := 24.0
const ROW_HEIGHT := 16.0
const ROW_GAP := 2.0
const ICON_AREA := 14.0 # The square at a row's left the 12-pixel icon is centred in
const TEXT_LEFT := 19.0 # From a row's left edge to its name and description
const PRICE_TOP := 2.0 # From a row's top edge to the price's coin, a pixel clear of the outline
const DESCRIPTION_TOP := 11.0 # Low enough to clear the coin where a long description runs under it
const HINTS_TOP := SIZE.y - 15.0
const MESSAGE_TOP := HINTS_TOP - 9.0
const VISIBLE_ROWS := int((MESSAGE_TOP - 2.0 - LIST_TOP + ROW_GAP) / (ROW_HEIGHT + ROW_GAP))
const ARROW := 5 # Art pixels across the "more above / below" arrows

# Font sizes, in art pixels.
const TITLE_SIZE := 5.0
const NAME_SIZE := 4.0
const DESCRIPTION_SIZE := 3.0
const TEXT_SIZE := 4.0 # The message and button hints

# Each tab: its title, what it sells (Upgrades or Items) and the stock, in order.
enum Sells { UPGRADES, ITEMS }
const TABS: Array[Dictionary] = [
	{title = "Upgrades", sells = Sells.UPGRADES, stock = [Upgrades.Kind.TIME, Upgrades.Kind.LOOTING]},
	{title = "Items", sells = Sells.ITEMS, stock = [Items.Kind.SKELETON_KEY, Items.Kind.METAL_DETECTOR]},
]
const UPGRADES_TAB := 0
const ITEMS_TAB := 1
const MAX_COLOR := Color8(248, 184, 0) # "Max" on a full upgrade: the minimap's key-room yellow

const FONT := preload("res://assets/fonts/8-BIT WONDER.TTF")
const COIN := preload("res://assets/sprites/hud/coin.png")
const COIN_FRAME := Rect2(0, 0, 7, 7) # coin.png is a sheet of spinning frames
const PANEL_FILL := Color(0.1, 0.1, 0.12) # Opaque, so the paused game doesn't show through
const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const DIM_TEXT := Color(0.62, 0.6, 0.66)
const TOO_DEAR := Color(1, 0.4, 0.4) # A price the player can't pay

const FLASH_TIME := 0.25
const OPEN_RISE := 12.0 # Art pixels below its place the panel starts as it opens
const OPEN_TIME := 0.22 # Seconds to rise into place
const OPEN_FADE_TIME := 0.12 # Seconds to fade in, quicker than the rise
const REFUSE_TIME := 0.3
const SHAKE_DISTANCE := 2.0 # Art pixels the refused row swings at first
const SHAKE_SWINGS := 2
const MESSAGE_TIME := 1.6 # Seconds a "can't buy" or "bought" line stays

# Placeholder (PENDING_ASSETS.md), shared with the item bar: the jammed bow's click.
const REFUSED_SOUND := preload("res://assets/sfx/clank_bad.wav")
const REFUSED_PITCH := 1.6
const REFUSED_VOLUME_DB := -8.0

const CONFIRM_ACTIONS: Array[String] = ["interact", "select", "ui_accept"]

signal closed

var _tab := 0
var _row := 0
var _scroll := 0 # First row shown
var _opened_frame := -1 # The interact press that opened the shop mustn't also buy
var _confirm_released := false # Confirm has been let go since opening or the last purchase
var _replacing := Items.Kind.NONE # The item waiting for a box to replace, while choosing one
var _next_buy_at := 0 # Ticks (ms, real time) before which another purchase is ignored
var _flash := 0.0 # White over the row just bought from, 1 to 0
var _refused := 0.0 # How far through the refused shake, 1 to 0
var _message := ""
var _message_color := TEXT_COLOR
var _message_left := 0.0 # Real seconds the message has left
var _flash_tween: Tween
var _rise := 0.0 # Art pixels the panel is still below its place while opening
var _open_tween: Tween
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
	_tab = UPGRADES_TAB
	_row = 0
	_scroll = 0
	_confirm_released = false
	_message = ""
	_animate_open()
	queue_redraw()

# Rises into place with a small overshoot and fades in, in real time.
func _animate_open() -> void:
	if _open_tween:
		_open_tween.kill()
	_rise = OPEN_RISE
	modulate.a = 0.0
	_open_tween = create_tween().set_ignore_time_scale().set_parallel()
	var rise := _open_tween.tween_method(_set_rise, OPEN_RISE, 0.0, OPEN_TIME)
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_FADE_TIME)

func _set_rise(value: float) -> void:
	_rise = value
	queue_redraw()

func close() -> void:
	_stop_replacing()
	visible = false
	get_tree().paused = false
	closed.emit()

func stock() -> Array:
	return TABS[_tab].stock

func _sells_upgrades() -> bool:
	return TABS[_tab].sells == Sells.UPGRADES

# Switches to tab `index` with its first row selected.
func show_tab(index: int) -> void:
	_change_tab(index - _tab)

# True while the shop is waiting for the player to choose a box on the item bar to replace.
func is_replacing() -> bool:
	return _replacing != Items.Kind.NONE

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
	if !_confirm_released && !_held(CONFIRM_ACTIONS):
		_confirm_released = true
	if is_replacing():
		_process_replacing()
	elif _pressed(["ui_cancel", "pause"]):
		close()
	elif _pressed(["up", "ui_up"]):
		_move(-1)
	elif _pressed(["down", "ui_down"]):
		_move(1)
	elif _pressed(["item_previous", "ui_left"]):
		_change_tab(-1)
	elif _pressed(["item_next", "ui_right"]):
		_change_tab(1)
	elif _pressed(CONFIRM_ACTIONS) && _confirm_released && Time.get_ticks_msec() >= _next_buy_at:
		buy_selected()

# Choosing a box on the item bar to swap for the new item.
func _process_replacing() -> void:
	if _pressed(["ui_cancel", "pause"]):
		_stop_replacing()
		_message = ""
		queue_redraw()
	elif _pressed(["item_previous", "ui_left", "left"]):
		Game.cycle_item(-1)
	elif _pressed(["item_next", "ui_right", "right"]):
		Game.cycle_item(1)
	elif _pressed(CONFIRM_ACTIONS) && _confirm_released && Time.get_ticks_msec() >= _next_buy_at:
		replace_selected_box()

# Throws away the item in the item bar's highlighted box and puts the new one there.
func replace_selected_box() -> void:
	var kind := _replacing
	match Game.replace_item(Game.item_slot, kind):
		Game.Purchase.BOUGHT:
			_stop_replacing()
			_bought()
		Game.Purchase.SAME_ITEM:
			# Still choosing: another box may hold something else.
			_refuse("That box already holds one. Choose another", false)
		_:
			_stop_replacing()
			_refuse("Not enough coins")

func _start_replacing(kind: Items.Kind) -> void:
	_replacing = kind
	# Start on a box that can be swapped, if the highlighted one holds the same item.
	if Game.item_in(Game.item_slot) == kind:
		for step in range(1, maxi(Tuning.item_slots, 1)):
			if Game.item_in(posmod(Game.item_slot + step, maxi(Tuning.item_slots, 1))) != kind:
				Game.cycle_item(step)
				break
	_confirm_released = false # The press that asked to buy mustn't also pick the box
	Game.set_choosing_item(true)
	_message = "Item bar full. Choose a box to replace"
	_message_color = TEXT_COLOR
	_message_left = 0.0 # Stays until the choice is made
	queue_redraw()

func _stop_replacing() -> void:
	if is_replacing():
		_replacing = Items.Kind.NONE
		Game.set_choosing_item(false)

func _pressed(actions: Array[String]) -> bool:
	for action in actions:
		if Input.is_action_just_pressed(action):
			return true
	return false

func _held(actions: Array[String]) -> bool:
	for action in actions:
		if Input.is_action_pressed(action):
			return true
	return false

func _move(step: int) -> void:
	_row = posmod(_row + step, maxi(stock().size(), 1))
	# Scroll just far enough to keep the selected row in view.
	_scroll = clampi(_scroll, _row - VISIBLE_ROWS + 1, _row)
	queue_redraw()

func _change_tab(step: int) -> void:
	_tab = posmod(_tab + step, TABS.size())
	_row = 0
	_scroll = 0
	queue_redraw()

# Buys the selected row's upgrade or item, or says why it can't.
func buy_selected() -> void:
	if _sells_upgrades():
		match Upgrades.buy(stock()[_row]):
			Game.Purchase.BOUGHT:
				_bought()
			Game.Purchase.TOO_POOR:
				_refuse("Not enough coins")
			Game.Purchase.MAXED:
				_refuse("That upgrade is at its top level")
		return
	var kind: Items.Kind = stock()[_row]
	match Game.buy_item(kind):
		Game.Purchase.BOUGHT:
			_bought()
		Game.Purchase.TOO_POOR:
			_refuse("Not enough coins")
		Game.Purchase.BAR_FULL:
			if _every_box_holds(kind):
				_refuse("Every box already holds one")
			else:
				_start_replacing(kind)

func _every_box_holds(kind: Items.Kind) -> bool:
	for slot in maxi(Tuning.item_slots, 1):
		if Game.item_in(slot) != kind:
			return false
	return true

# A purchase went through: the row flashes and the coins clink, with no message (and any
# left from choosing a box to swap is cleared).
func _bought() -> void:
	_confirm_released = false
	_next_buy_at = Time.get_ticks_msec() + roundi(Tuning.shop_buy_cooldown * 1000.0)
	_message = ""
	queue_redraw()
	Juice.coin_stolen_sound() # Coins leaving the purse
	_flash_tween = _restart(_flash_tween, _set_flash, FLASH_TIME)

# Says why, with the refused click and a red shake; `fades` false keeps the message up.
func _refuse(why: String, fades := true) -> void:
	_say(why, TOO_DEAR)
	if !fades:
		_message_left = 0.0
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

# The panel's top-left, centred on the screen; while opening, lower by _rise (on whole art
# pixels, so the frame stays crisp).
func _origin() -> Vector2:
	return ((get_viewport_rect().size / UNIT - SIZE) / 2.0).floor() + Vector2(0, roundf(_rise))

func _draw() -> void:
	var o := _origin()
	HudFrame.backing(self, Rect2(o, SIZE), UNIT, PANEL_FILL)
	_draw_tabs(o)
	_draw_coins(o)
	HudFrame.fill(self, Rect2(o + Vector2(MARGIN, LIST_TOP - 4), Vector2(SIZE.x - MARGIN * 2, 1)),
		ItemBar.Minimap.UNLIT, UNIT)
	var items := stock()
	for i in range(_scroll, mini(_scroll + VISIBLE_ROWS, items.size())):
		_draw_row(o, i, items[i])
	_draw_scroll_arrows(o, items.size())
	if _message != "":
		_text(_message, o + Vector2(0, MESSAGE_TOP), TEXT_SIZE, _message_color,
			HORIZONTAL_ALIGNMENT_CENTER, SIZE.x)
	_draw_hints(o)

# Tabs sized to their titles, left to right.
func _draw_tabs(o: Vector2) -> void:
	var x := o.x + MARGIN
	for i in TABS.size():
		var width := _text_width(String(TABS[i].title), TITLE_SIZE) + TAB_PADDING * 2
		var tab := Rect2(Vector2(x, o.y + TAB_TOP), Vector2(width, TAB_HEIGHT))
		x += width + TAB_GAP
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

func _draw_row(o: Vector2, index: int, entry: int) -> void:
	var row := Rect2(o + Vector2(MARGIN, LIST_TOP + (index - _scroll) * (ROW_HEIGHT + ROW_GAP)),
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

	var icon_area := Rect2(row.position + Vector2(2, (ROW_HEIGHT - ICON_AREA) / 2.0).floor(),
		Vector2(ICON_AREA, ICON_AREA))
	var upgrade := _sells_upgrades()
	var icon: Texture2D = Upgrades.ICONS[entry] if upgrade else Items.ICONS[entry]
	var icon_at := (icon_area.get_center() - icon.get_size() / 2.0).floor()
	draw_texture_rect(icon, Rect2(icon_at * UNIT, icon.get_size() * UNIT), false)

	var title: String = _upgrade_title(entry) if upgrade else String(Items.INFO[entry].name)
	var description: String = Upgrades.description(entry) if upgrade else String(Items.INFO[entry].text)
	var text_left := row.position.x + TEXT_LEFT
	_text(title, Vector2(text_left, row.position.y + 3), NAME_SIZE, TEXT_COLOR)
	_text(description, Vector2(text_left, row.position.y + DESCRIPTION_TOP), DESCRIPTION_SIZE, DIM_TEXT)

	var right := row.end.x - 3
	var price := Upgrades.price(entry) if upgrade else Items.price(entry)
	if price < 0:
		var width := _text_width("Max", NAME_SIZE)
		_text("Max", Vector2(right - width, row.position.y + PRICE_TOP + 2), NAME_SIZE, MAX_COLOR)
	else:
		var price_text := str(price)
		var width := _text_width(price_text, NAME_SIZE)
		_text(price_text, Vector2(right - width, row.position.y + PRICE_TOP + 2), NAME_SIZE,
			TEXT_COLOR if Game.coins >= price else TOO_DEAR)
		_coin(Vector2(right - width - COIN_FRAME.size.x - 1, row.position.y + PRICE_TOP))

	if selected && _flash > 0.0:
		HudFrame.fill(self, row, Color(1, 1, 1, 0.6 * _flash), UNIT)

# The upgrade's name with the level the row sells: nothing for the first, then "Lv. 2" and
# on. A full upgrade keeps its last level.
func _upgrade_title(kind: Upgrades.Kind) -> String:
	var level := mini(Upgrades.level(kind) + 1, Upgrades.MAX_LEVEL)
	var title: String = Upgrades.NAMES[kind]
	return title if level <= 1 else "%s Lv. %d" % [title, level]

# Small arrows at the right of the list when rows are hidden above or below it.
func _draw_scroll_arrows(o: Vector2, count: int) -> void:
	var x := o.x + SIZE.x - MARGIN - ARROW
	if _scroll > 0:
		_arrow(Vector2(x, o.y + LIST_TOP - 3), -1)
	if _scroll + VISIBLE_ROWS < count:
		_arrow(Vector2(x, o.y + LIST_TOP + VISIBLE_ROWS * (ROW_HEIGHT + ROW_GAP) - 1), 1)

# A 5-wide, 3-tall triangle with its flat side at `at`, pointing up (-1) or down (1).
func _arrow(at: Vector2, direction: int) -> void:
	for i in 3:
		var y := at.y + (i if direction > 0 else -i)
		HudFrame.fill(self, Rect2(at.x + i, y, ARROW - i * 2, 1), TEXT_COLOR, UNIT)

# Confirm to buy and back to leave, as buttons for the device in use, centred at the bottom.
func _draw_hints(o: Vector2) -> void:
	var hints := [[InputGlyphs.Glyph.CONFIRM, "Replace"], [InputGlyphs.Glyph.BACK, "Cancel"]] \
		if is_replacing() else [[InputGlyphs.Glyph.CONFIRM, "Buy"], [InputGlyphs.Glyph.BACK, "Close"]]
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

func _text_width(text: String, size: float) -> float:
	return ceilf(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * UNIT)).x / UNIT)
