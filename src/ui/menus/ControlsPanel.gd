extends Control
class_name ControlsPanel

# Controls sub-panel of the shared options screen. Each row has one keyboard key and one
# controller button to capture; clicking either starts listening for a press. Bindings are
# changed through the Bindings autoload, which updates InputMap and the save data at once.
# The host saves to disk when it closes the options screen. Escape/B cancels a capture.

signal back_pressed

const FONT: FontFile = preload("res://assets/fonts/8-BIT WONDER.TTF")
const DEVICE_KEY := "key"
const DEVICE_BUTTON := "button"
const CAPTION := "PRESS A KEY OR PAD BUTTON - ESC CANCELS"

@onready var rows: VBoxContainer = $Panel/Rows
@onready var status_label: Label = $Panel/Status
@onready var back_button: Button = $Panel/Back
@onready var reset_button: Button = $Panel/Reset

var _key_buttons := {}
var _pad_buttons := {}
var _listening_action := ""
var _listening_device := ""

func _ready() -> void:
	_build_rows()
	back_button.pressed.connect(back_pressed.emit)
	reset_button.pressed.connect(_on_reset_pressed)
	status_label.text = CAPTION

func refresh() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = "KEY: %s" % Bindings.key_name(Bindings.key_for(action))
		(_pad_buttons[action] as Button).text = "PAD: %s" % Bindings.button_name(Bindings.button_for(action))

func focus_first() -> void:
	var first: Button = _key_buttons.get(String(Bindings.ACTIONS[0]["action"])) as Button
	if first != null:
		first.grab_focus()

func is_listening() -> bool:
	return !_listening_action.is_empty()

# Public so the buttons and tests can start a capture the same way.
func start_capture(action: String, device: String) -> void:
	if !Bindings.bindings.has(action):
		return
	_listening_action = action
	_listening_device = device
	refresh()
	var button := _button_for_device(action, device)
	if button != null:
		button.text = "PRESS KEY..." if device == DEVICE_KEY else "PRESS PAD..."
	status_label.text = "%s: %s" % [Bindings.action_label(action), CAPTION]

func _input(event: InputEvent) -> void:
	if !is_listening():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if !key_event.pressed || key_event.echo:
			return
		# Escape is reserved for the host to cancel the capture, never for a binding.
		if key_event.keycode == KEY_ESCAPE:
			return
		_consume()
		if key_event.ctrl_pressed || key_event.meta_pressed || key_event.alt_pressed \
				|| _is_modifier(key_event.keycode):
			status_label.text = "MODIFIER KEYS CANNOT BE BOUND"
			return
		_finish_key(key_event.keycode)
		return
	if event is InputEventJoypadButton:
		var pad_event := event as InputEventJoypadButton
		if !pad_event.pressed:
			return
		_consume()
		_finish_button(pad_event.button_index)

func _build_rows() -> void:
	for entry: Dictionary in Bindings.ACTIONS:
		var action := String(entry["action"])
		var row := HBoxContainer.new()
		row.name = "Row_%s" % action
		row.custom_minimum_size.y = 20.0
		var label := Label.new()
		label.text = Bindings.action_label(action)
		label.custom_minimum_size.x = 200.0
		_style_control(label)
		row.add_child(label)
		var key_button := Button.new()
		key_button.name = "Key"
		key_button.custom_minimum_size.x = 160.0
		key_button.pressed.connect(_on_key_pressed.bind(action))
		_style_control(key_button)
		row.add_child(key_button)
		_key_buttons[action] = key_button
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
	Bindings.reset_defaults()
	refresh()
	status_label.text = "DEFAULT BINDINGS RESTORED"

func _finish_key(keycode: int) -> void:
	if keycode == Bindings.key_for(_listening_action):
		_stop_capture()
		return
	var owner := Bindings.key_owner(keycode)
	if !owner.is_empty() && owner != _listening_action:
		status_label.text = "%s IS ALREADY USED BY %s" % [Bindings.key_name(keycode), Bindings.action_label(owner)]
		return
	Bindings.set_key(_listening_action, keycode)
	status_label.text = "%s KEY SET TO %s" % [Bindings.action_label(_listening_action), Bindings.key_name(keycode)]
	_stop_capture()

func _finish_button(button_index: int) -> void:
	if button_index == Bindings.button_for(_listening_action):
		_stop_capture()
		return
	var owner := Bindings.button_owner(button_index)
	if !owner.is_empty() && owner != _listening_action:
		status_label.text = "%s IS ALREADY USED BY %s" % [Bindings.button_name(button_index), Bindings.action_label(owner)]
		return
	Bindings.set_button(_listening_action, button_index)
	status_label.text = "%s PAD SET TO %s" % [Bindings.action_label(_listening_action), Bindings.button_name(button_index)]
	_stop_capture()

# Called by the hosts when Escape arrives while a capture is active.
func cancel_capture() -> void:
	status_label.text = "CAPTURE CANCELLED"
	_stop_capture()

func _stop_capture() -> void:
	_listening_action = ""
	_listening_device = ""
	refresh()

func _button_for_device(action: String, device: String) -> Button:
	if device == DEVICE_KEY:
		return _key_buttons.get(action) as Button
	return _pad_buttons.get(action) as Button

func _is_modifier(keycode: int) -> bool:
	return keycode == KEY_CTRL || keycode == KEY_SHIFT || keycode == KEY_ALT || keycode == KEY_META

func _consume() -> void:
	get_viewport().set_input_as_handled()
