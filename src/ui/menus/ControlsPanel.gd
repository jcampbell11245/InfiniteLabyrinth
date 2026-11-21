extends Control
class_name ControlsPanel

# Controls sub-panel of the shared options screen. Each row has one keyboard key and one
# controller button to capture; clicking either starts listening for a press. Bindings are
# changed through the Bindings autoload, which updates InputMap and the save data at once.
# The host saves to disk when it closes the options screen. Escape cancels a capture at once.
# B is both a bindable pad button and the pad cancel: a quick tap binds it, while holding it
# briefly cancels so a stray press cannot abandon a rebind. F1 and F2 are refused because the
# room creator and debug menu read them directly.

signal back_pressed

const FONT: FontFile = preload("res://assets/fonts/8-BIT WONDER.TTF")
const DEVICE_KEY := "key"
const DEVICE_BUTTON := "button"
const CANCEL_HINT := "ESC TO CANCEL   HOLD B TO CANCEL"
const RESERVED_KEY_STATUS := "F1 AND F2 ARE RESERVED"
const PAD_CANCEL_HOLD_SECONDS := 0.6
const STATUS_SECONDS := 3.0

@onready var rows: VBoxContainer = $Panel/Rows
@onready var status_label: Label = $Panel/Status
@onready var back_button: Button = $Panel/Back
@onready var reset_button: Button = $Panel/Reset

var _key_buttons := {}
var _pad_buttons := {}
var _listening_action := ""
var _listening_device := ""
var _pad_cancel_started_msec := -1 # -1 while B is not held; real time so slow motion can't stretch it.
var _status_generation := 0 # Stale timers from earlier messages must not clear a newer blurb.

func _ready() -> void:
	_build_rows()
	back_button.pressed.connect(back_pressed.emit)
	reset_button.pressed.connect(_on_reset_pressed)
	_set_status("")

func _notification(what: int) -> void:
	# Mouse clicks, Android go-back and a hidden parent all bypass Back's signal.
	if what == NOTIFICATION_VISIBILITY_CHANGED && !is_visible_in_tree():
		_stop_capture()

func refresh() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = Bindings.key_name(Bindings.key_for(action))
		(_pad_buttons[action] as Button).text = Bindings.button_name(Bindings.button_for(action))

func focus_first() -> void:
	var first: Button = _key_buttons.get(String(Bindings.ACTIONS[0]["action"])) as Button
	if first != null:
		first.grab_focus()

func is_listening() -> bool:
	return !_listening_action.is_empty()

# Public so the host can abandon a capture when it leaves the controls page.
func stop_capture() -> void:
	_stop_capture()

# Public so the buttons and tests can start a capture the same way.
func start_capture(action: String, device: String) -> void:
	if !Bindings.bindings.has(action):
		return
	_listening_action = action
	_listening_device = device
	_pad_cancel_started_msec = -1
	# The hint stays up for as long as the panel waits for input.
	_set_status(CANCEL_HINT, true)
	refresh()
	var button := _button_for_device(action, device)
	if button != null:
		button.text = "PRESS KEY" if device == DEVICE_KEY else "PRESS PAD"

func _input(event: InputEvent) -> void:
	if !is_listening():
		return
	if event is InputEventJoypadButton:
		var pad_event := event as InputEventJoypadButton
		if pad_event.button_index == JOY_BUTTON_B:
			_consume()
			if pad_event.pressed:
				_handle_pad_cancel(true)
				return
			# A short press is a normal button choice; only a held B cancels.
			var was_holding := _pad_cancel_started_msec >= 0
			_handle_pad_cancel(false)
			if was_holding && is_listening() && _listening_device == DEVICE_BUTTON:
				_finish_button(JOY_BUTTON_B)
			return
		# A held B owns the capture, so another pad button must not change the binding.
		if _pad_cancel_started_msec >= 0:
			_consume()
			return
		# A key capture never accepts pad buttons; B above is the shared cancel exception.
		if _listening_device != DEVICE_BUTTON:
			_consume()
			return
		if !pad_event.pressed:
			return
		_consume()
		_finish_button(pad_event.button_index)
		return
	if _pad_cancel_started_msec >= 0:
		_consume()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if !key_event.pressed || key_event.echo:
			return
		# Escape is reserved for the host to cancel the capture, never for a binding.
		if key_event.keycode == KEY_ESCAPE:
			return
		# A pad capture never accepts keys; Escape above remains the shared cancel.
		if _listening_device != DEVICE_KEY:
			_consume()
			return
		_consume()
		if key_event.ctrl_pressed || key_event.meta_pressed || key_event.alt_pressed \
				|| _is_modifier(key_event.keycode):
			_set_status("MODIFIER KEYS CANNOT BE BOUND")
			return
		_finish_key(key_event.keycode)

func _process(_delta: float) -> void:
	if _pad_cancel_started_msec < 0 || !is_listening():
		return
	# Real time matters here: hit-stop and slow motion must not stretch the hold.
	var held_ms := Time.get_ticks_msec() - _pad_cancel_started_msec
	if held_ms >= int(PAD_CANCEL_HOLD_SECONDS * 1000.0):
		_pad_cancel_started_msec = -1
		cancel_capture()

func _handle_pad_cancel(pressed: bool) -> void:
	if !pressed:
		_pad_cancel_started_msec = -1
		return
	# Ignore auto-repeat: the hold starts on the first press and ends on release.
	if _pad_cancel_started_msec < 0:
		_pad_cancel_started_msec = Time.get_ticks_msec()

func _build_rows() -> void:
	for entry: Dictionary in Bindings.ACTIONS:
		var action := String(entry["action"])
		var row := HBoxContainer.new()
		row.name = "Row_%s" % action
		row.custom_minimum_size.y = 20.0
		# The spacer supplies the column gap; a container gap would also indent the labels.
		row.add_theme_constant_override(&"separation", 0)
		var label := Label.new()
		label.text = Bindings.action_label(action)
		label.custom_minimum_size.x = 180.0
		_style_control(label)
		row.add_child(label)
		var key_button := Button.new()
		key_button.name = "Key"
		key_button.custom_minimum_size.x = 160.0
		key_button.pressed.connect(_on_key_pressed.bind(action))
		_style_control(key_button)
		row.add_child(key_button)
		_key_buttons[action] = key_button
		# A spacer keeps the two columns apart without also indenting the action labels.
		var gap := Control.new()
		gap.name = "Gap"
		gap.custom_minimum_size.x = 16.0
		row.add_child(gap)
		var pad_button := Button.new()
		pad_button.name = "Pad"
		pad_button.custom_minimum_size.x = 160.0
		pad_button.pressed.connect(_on_pad_pressed.bind(action))
		_style_control(pad_button)
		row.add_child(pad_button)
		_pad_buttons[action] = pad_button
		rows.add_child(row)
	refresh()

func _style_control(control: Control) -> void:
	control.add_theme_font_override(&"font", FONT)
	control.add_theme_font_size_override(&"font_size", 12)
	control.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	if control is Button:
		control.add_theme_color_override(&"font_focus_color", Color(1, 1, 0.65, 1))

func _on_key_pressed(action: String) -> void:
	start_capture(action, DEVICE_KEY)

func _on_pad_pressed(action: String) -> void:
	start_capture(action, DEVICE_BUTTON)

func _on_reset_pressed() -> void:
	stop_capture()
	Bindings.reset_defaults()
	refresh()
	_set_status("DEFAULT BINDINGS RESTORED")

func _finish_key(keycode: int) -> void:
	if keycode == Bindings.key_for(_listening_action):
		_stop_capture()
		return
	if Bindings.is_reserved_key(keycode):
		_set_status(RESERVED_KEY_STATUS)
		return
	var owner := Bindings.key_owner(keycode, _listening_action)
	if !owner.is_empty() && owner != _listening_action:
		# Only say reserved when the owner's row hides the key; a visible binding is "used by".
		var relation := "USED BY"
		if Bindings.is_fixed_alternate(keycode, owner):
			relation = "RESERVED FOR"
		_set_status("%s IS ALREADY %s %s" % [Bindings.key_name(keycode), relation,
				Bindings.action_label(owner)])
		return
	Bindings.set_key(_listening_action, keycode)
	_set_status("%s KEY SET TO %s" % [Bindings.action_label(_listening_action), Bindings.key_name(keycode)])
	_stop_capture()

func _finish_button(button_index: int) -> void:
	if button_index == Bindings.button_for(_listening_action):
		_stop_capture()
		return
	var owner := Bindings.button_owner(button_index)
	if !owner.is_empty() && owner != _listening_action:
		_set_status("%s IS ALREADY USED BY %s" % [Bindings.button_name(button_index), Bindings.action_label(owner)])
		return
	Bindings.set_button(_listening_action, button_index)
	_set_status("%s PAD SET TO %s" % [Bindings.action_label(_listening_action), Bindings.button_name(button_index)])
	_stop_capture()

# Called by the host for Escape and by the hold timer for B.
func cancel_capture() -> void:
	_set_status("CAPTURE CANCELLED")
	_stop_capture()

# Feedback is transient: it clears after a short real-time delay, even while paused or slowed.
# The capture hint is persistent so players always know how to cancel while choosing an input.
func _set_status(message: String, persistent := false) -> void:
	status_label.text = message
	status_label.visible = !message.is_empty()
	_status_generation += 1
	if message.is_empty() || persistent:
		return
	var generation := _status_generation
	var timer := get_tree().create_timer(STATUS_SECONDS, true, false, true)
	timer.timeout.connect(_on_status_timeout.bind(generation))

func _on_status_timeout(generation: int) -> void:
	if generation != _status_generation:
		return
	# A conflict message can replace the hint during a capture; bring it back afterwards.
	if is_listening():
		_set_status(CANCEL_HINT, true)
	else:
		_set_status("")

func _stop_capture() -> void:
	_listening_action = ""
	_listening_device = ""
	_pad_cancel_started_msec = -1
	refresh()

func _button_for_device(action: String, device: String) -> Button:
	if device == DEVICE_KEY:
		return _key_buttons.get(action) as Button
	return _pad_buttons.get(action) as Button

func _is_modifier(keycode: int) -> bool:
	return keycode == KEY_CTRL || keycode == KEY_SHIFT || keycode == KEY_ALT || keycode == KEY_META

func _consume() -> void:
	get_viewport().set_input_as_handled()
