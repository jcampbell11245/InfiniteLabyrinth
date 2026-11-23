class_name DialogueBox
extends Control

# A text box along the bottom of the screen for characters to talk to the player, with the
# speaker's name on a tag over its top-left corner. Anyone with something to say adds one
# (on a CanvasLayer over the HUD, like Merchant does) and calls say() with a name and one or
# more lines; `finished` fires once the last line is dismissed.
#
# Each line types out a letter at a time (Tuning.dialogue_chars_per_second) with a short
# blip every few letters. Select (A / cross on a pad, J or Enter on the keyboard) first
# finishes the line at once if it's still typing, and once it's all shown moves on to the
# next line, or closes the box after the last. A small arrow bobs in the corner when the
# line is waiting to be moved on.
#
# Lines are wrapped on the whole line before any of it shows, so words never jump down a row
# as they type. The game is paused while the box is up, so it runs with
# PROCESS_MODE_ALWAYS and counts real time. Like ShopMenu it's drawn in code on an unscaled
# layer, in art pixels UNIT screen pixels across, so its frame matches the 5x HUD.

const UNIT := 5.0 # Screen pixels per art pixel, matching HudLayer's scale
const WIDTH := 220.0 # The box, in art pixels
const HEIGHT := 40.0
const BOTTOM_GAP := 10.0 # From the box's bottom edge to the screen's
const PADDING := 8.0 # From the box's edge to the text, left and right
const TEXT_TOP := 9.0 # From the box's top edge to the first line, clear of the name tag
const LINE_HEIGHT := 8.0
const MAX_ROWS := 3 # Rows of text the box has room for

const TAG_LEFT := 6.0 # From the box's left edge to the name tag's
const TAG_HEIGHT := 11.0
const TAG_RISE := 6.0 # How far the tag stands up over the box's top edge
const TAG_PADDING := 5.0 # Each side of the name

const TEXT_SIZE := 5.0 # Font sizes, in art pixels
const NAME_SIZE := 4.0

const ARROW := 5 # Art pixels across the "more to come" arrow
const ARROW_BOB := 1.0 # Art pixels it bobs up and down
const ARROW_PERIOD := 0.6 # Seconds per bob, in real time

const OPEN_FADE_TIME := 0.1 # Seconds to fade in

const FONT := preload("res://assets/fonts/8-BIT WONDER.TTF")
const PANEL_FILL := Color(0.1, 0.1, 0.12)
const TEXT_COLOR := Color(0.92, 0.9, 0.86)
const NAME_COLOR := Color8(248, 184, 0) # The minimap's key-room yellow, as on the shop's "Max"

# Placeholder (PENDING_ASSETS.md): a synthesized pulse-wave blip.
const BLIP_SOUND := preload("res://assets/sfx/dialogue_blip.wav")
const BLIP_VOLUME_DB := -10.0
const BLIP_SPREAD := 0.05 # Pitch varies this much either way, so it doesn't drone

const ADVANCE_ACTIONS: Array[String] = ["select"]

signal finished

var _speaker := ""
var _lines: Array[String] = []
var _line := 0 # Index into _lines of the one showing
var _rows: Array[String] = [] # The line showing, wrapped to the box
var _total := 0 # Letters in _rows
var _shown := 0 # Letters typed so far
var _progress := 0.0 # Letters' worth of time typed, fractional
var _letters_since_blip := 0
var _opened_frame := -1 # The press that opened the box mustn't also skip its typing
var _paused_before := false
var _open_tween: Tween
var _blip: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_blip = AudioStreamPlayer.new()
	_blip.bus = &"SFX"
	_blip.stream = BLIP_SOUND
	_blip.volume_db = BLIP_VOLUME_DB
	add_child(_blip)

# Shows `lines` one after another, spoken by `speaker`, pausing the game until the last is
# dismissed.
func say(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_speaker = speaker
	_lines = lines
	_paused_before = get_tree().paused if !visible else _paused_before
	visible = true
	get_tree().paused = true
	_opened_frame = Engine.get_process_frames()
	_show_line(0)
	_fade_in()

# True while the current line is still typing out.
func is_typing() -> bool:
	return visible && _shown < _total

# The letters of the current line shown so far.
func shown_text() -> String:
	var text := "".join(_rows)
	return text.substr(0, _shown)

# What the advance button does: finish the line if it's typing, otherwise move on.
func advance() -> void:
	if !visible:
		return
	if is_typing():
		_shown = _total
		_progress = _total
		queue_redraw()
	elif _line + 1 < _lines.size():
		_show_line(_line + 1)
	else:
		close()

func close() -> void:
	if !visible:
		return
	visible = false
	get_tree().paused = _paused_before
	finished.emit()

func _show_line(index: int) -> void:
	_line = index
	_rows = _wrap(_lines[index])
	_total = 0
	for row in _rows:
		_total += row.length()
	_shown = 0
	_progress = 0.0
	_letters_since_blip = 0
	queue_redraw()

func _fade_in() -> void:
	if _open_tween:
		_open_tween.kill()
	modulate.a = 0.0
	_open_tween = create_tween().set_ignore_time_scale()
	_open_tween.tween_property(self, "modulate:a", 1.0, OPEN_FADE_TIME)

func _process(delta: float) -> void:
	if !visible:
		return
	if is_typing():
		# delta is real time here: the tree is paused, but Engine.time_scale still applies.
		_progress += delta / maxf(Engine.time_scale, 0.01) * Tuning.dialogue_chars_per_second
		_type_to(mini(floori(_progress), _total))
	queue_redraw() # The typing, and the arrow's bob
	if Engine.get_process_frames() == _opened_frame:
		return
	for action in ADVANCE_ACTIONS:
		if Input.is_action_just_pressed(action):
			advance()
			return

# Reveals letters up to `count`, blipping once if enough of them were letters.
func _type_to(count: int) -> void:
	var text := "".join(_rows)
	var blip := false
	while _shown < count:
		var c := text.unicode_at(_shown)
		_shown += 1
		if _is_letter(c):
			_letters_since_blip += 1
			if _letters_since_blip >= maxi(Tuning.dialogue_blip_every, 1):
				_letters_since_blip = 0
				blip = true
	if blip:
		Juice.play(_blip, BLIP_SPREAD)

func _is_letter(c: int) -> bool:
	return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57)

# Splits `text` into rows that fit the box, breaking between words.
func _wrap(text: String) -> Array[String]:
	var rows: Array[String] = []
	var room := WIDTH - PADDING * 2
	var row := ""
	for word in text.split(" ", false):
		var tried := word if row == "" else row + " " + word
		if row != "" && _text_width(tried, TEXT_SIZE) > room:
			rows.append(row)
			row = word
		else:
			row = tried
	if row != "":
		rows.append(row)
	if rows.size() > MAX_ROWS:
		push_warning("Dialogue line too long for the box: \"%s\"" % text)
	return rows

# --- Drawing (all in art pixels, scaled by UNIT) ---

func _origin() -> Vector2:
	var screen := get_viewport_rect().size / UNIT
	return Vector2(floorf((screen.x - WIDTH) / 2.0), floorf(screen.y - BOTTOM_GAP - HEIGHT))

func _draw() -> void:
	var o := _origin()
	HudFrame.backing(self, Rect2(o, Vector2(WIDTH, HEIGHT)), UNIT, PANEL_FILL)
	_draw_name_tag(o)
	var left := _shown
	for i in _rows.size():
		if left <= 0:
			break
		var row := _rows[i]
		_text(row.substr(0, left), o + Vector2(PADDING, TEXT_TOP + i * LINE_HEIGHT), TEXT_SIZE, TEXT_COLOR)
		left -= row.length()
	if !is_typing():
		_draw_arrow(o)

# The speaker's name on a tag standing up over the box's top-left corner.
func _draw_name_tag(o: Vector2) -> void:
	if _speaker == "":
		return
	var width := _text_width(_speaker, NAME_SIZE) + TAG_PADDING * 2
	var tag := Rect2(o + Vector2(TAG_LEFT, -TAG_RISE), Vector2(width, TAG_HEIGHT))
	HudFrame.backing(self, tag, UNIT, PANEL_FILL)
	_text(_speaker, tag.position + Vector2(0, 3), NAME_SIZE, NAME_COLOR, HORIZONTAL_ALIGNMENT_CENTER, width)

# A small down arrow bobbing in the bottom-right corner: press to go on.
func _draw_arrow(o: Vector2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob := roundf(sin(t * TAU / ARROW_PERIOD) * ARROW_BOB)
	var at := o + Vector2(WIDTH - PADDING - ARROW, HEIGHT - 8 + bob)
	for i in 3:
		HudFrame.fill(self, Rect2(at.x + i, at.y + i, ARROW - i * 2, 1), TEXT_COLOR, UNIT)

# One line of text with its top-left corner at `at` (art pixels), aligned within `width`.
func _text(text: String, at: Vector2, size: float, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font_size := roundi(size * UNIT)
	var baseline := Vector2(at.x * UNIT, at.y * UNIT + FONT.get_ascent(font_size)).round()
	draw_string(FONT, baseline, text, align, width * UNIT if width > 0 else -1.0, font_size, color)

func _text_width(text: String, size: float) -> float:
	return ceilf(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size * UNIT)).x / UNIT)
