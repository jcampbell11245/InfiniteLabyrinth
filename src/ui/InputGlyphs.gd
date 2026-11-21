class_name InputGlyphs
extends RefCounted

# Button prompts that match what the player is holding: a keycap on the keyboard, a
# coloured A or B on an Xbox-style pad, a cross or circle on a PlayStation pad. Whoever
# shows prompts passes their input events to note(), so the glyphs follow the last device
# touched; until then a connected pad wins over the keyboard.
#
# The glyphs are drawn in code, in art pixels scaled by `unit` like HudFrame, so they need
# no sprites. CONFIRM is the interact / buy button, BACK closes menus.

enum Device { KEYBOARD, XBOX, PLAYSTATION }
enum Glyph { CONFIRM, BACK }

const FONT := preload("res://assets/fonts/8-BIT WONDER.TTF")
const KEY_TEXT := {Glyph.CONFIRM: "R", Glyph.BACK: "ESC"} # Must match project.godot's bindings
const XBOX_TEXT := {Glyph.CONFIRM: "A", Glyph.BACK: "B"}
const XBOX_COLOR := {Glyph.CONFIRM: Color8(60, 170, 70), Glyph.BACK: Color8(200, 50, 50)}
const PS_SYMBOL_COLOR := {Glyph.CONFIRM: Color8(120, 160, 255), Glyph.BACK: Color8(255, 90, 90)}
const PAD_FACE := Color8(40, 40, 48)
const KEYCAP := Color8(210, 210, 220)
const KEYCAP_SIDE := Color8(120, 120, 136)
const INK := Color8(20, 17, 24)
const SIZE := 9 # Art pixels across a round button or a one-letter keycap
const TEXT_SIZE := 6 # Font size, in art pixels, of the letters on the buttons
const PLAYSTATION_NAMES: Array[String] = ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]

static var _device := Device.KEYBOARD
static var _noted := false # An event has set _device

static func note(event: InputEvent) -> void:
	if event is InputEventKey || event is InputEventMouseButton:
		_use_device(Device.KEYBOARD)
	elif event is InputEventJoypadButton \
			|| (event is InputEventJoypadMotion && absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		_use_device(_pad_type(event.device))

static func device() -> Device:
	if !_noted:
		var pads := Input.get_connected_joypads()
		return _pad_type(pads[0]) if !pads.is_empty() else Device.KEYBOARD
	return _device

# Width in art pixels of `glyph` as drawn now: keycaps grow with their text.
static func width(glyph: Glyph) -> int:
	if device() != Device.KEYBOARD:
		return SIZE
	var text: String = KEY_TEXT[glyph]
	if text.length() == 1:
		return SIZE
	# Measured at a large size and scaled down, so it's the same at any unit.
	var measured := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE * 10).x / 10.0
	return maxi(SIZE, ceili(measured) + 5)

# Draws `glyph` with its top-left corner at `at` (art pixels).
static func draw(canvas: CanvasItem, glyph: Glyph, at: Vector2, unit := 1.0) -> void:
	match device():
		Device.KEYBOARD: _draw_key(canvas, glyph, at, unit)
		Device.XBOX: _draw_xbox(canvas, glyph, at, unit)
		Device.PLAYSTATION: _draw_playstation(canvas, glyph, at, unit)

static func _use_device(new_device: Device) -> void:
	_device = new_device
	_noted = true

static func _pad_type(pad: int) -> Device:
	var name := Input.get_joy_name(pad).to_lower()
	for word in PLAYSTATION_NAMES:
		if word in name:
			return Device.PLAYSTATION
	return Device.XBOX

# A light keycap with a darker front edge, the key's name on it.
static func _draw_key(canvas: CanvasItem, glyph: Glyph, at: Vector2, unit: float) -> void:
	var rect := Rect2(at, Vector2(width(glyph), SIZE))
	HudFrame.fill(canvas, Rect2(rect.position + Vector2(1, 0), rect.size - Vector2(2, 0)), INK, unit)
	HudFrame.fill(canvas, Rect2(rect.position + Vector2(0, 1), rect.size - Vector2(0, 2)), INK, unit)
	HudFrame.fill(canvas, rect.grow(-1), KEYCAP_SIDE, unit)
	HudFrame.fill(canvas, Rect2(rect.position + Vector2.ONE, rect.size - Vector2(2, 3)), KEYCAP, unit)
	_text(canvas, KEY_TEXT[glyph], Rect2(rect.position, rect.size - Vector2(0, 1)), INK, unit)

static func _draw_xbox(canvas: CanvasItem, glyph: Glyph, at: Vector2, unit: float) -> void:
	_disc(canvas, at, XBOX_COLOR[glyph], unit)
	_text(canvas, XBOX_TEXT[glyph], Rect2(at, Vector2(SIZE, SIZE)), Color.WHITE, unit)

static func _draw_playstation(canvas: CanvasItem, glyph: Glyph, at: Vector2, unit: float) -> void:
	_disc(canvas, at, PAD_FACE, unit)
	var color: Color = PS_SYMBOL_COLOR[glyph]
	if glyph == Glyph.CONFIRM:
		for i in 5: # A cross, one art pixel per step along each diagonal
			HudFrame.fill(canvas, Rect2(at + Vector2(2 + i, 2 + i), Vector2.ONE), color, unit)
			HudFrame.fill(canvas, Rect2(at + Vector2(6 - i, 2 + i), Vector2.ONE), color, unit)
	else:
		# A ring: 5x5 with its corners and middle left out.
		for strip: Rect2 in [Rect2(3, 2, 3, 1), Rect2(3, 6, 3, 1), Rect2(2, 3, 1, 3), Rect2(6, 3, 1, 3)]:
			HudFrame.fill(canvas, Rect2(at + strip.position, strip.size), color, unit)

# A round button: a 9x9 block with its corners cut, outlined in INK.
static func _disc(canvas: CanvasItem, at: Vector2, color: Color, unit: float) -> void:
	HudFrame.fill(canvas, Rect2(at + Vector2(2, 0), Vector2(5, 9)), INK, unit)
	HudFrame.fill(canvas, Rect2(at + Vector2(0, 2), Vector2(9, 5)), INK, unit)
	HudFrame.fill(canvas, Rect2(at + Vector2(1, 1), Vector2(7, 7)), INK, unit)
	HudFrame.fill(canvas, Rect2(at + Vector2(2, 1), Vector2(5, 7)), color, unit)
	HudFrame.fill(canvas, Rect2(at + Vector2(1, 2), Vector2(7, 5)), color, unit)

# `text` centred in `rect` (art pixels).
static func _text(canvas: CanvasItem, text: String, rect: Rect2, color: Color, unit: float) -> void:
	var size := roundi(TEXT_SIZE * unit)
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var box := Rect2(rect.position * unit, rect.size * unit)
	var left := roundf(box.get_center().x - text_size.x / 2.0)
	var baseline := roundf(box.get_center().y + (FONT.get_ascent(size) - FONT.get_descent(size)) / 2.0)
	canvas.draw_string(FONT, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
