extends Control

# First screen on launch. Start begins a run through Boot; Options opens the shared audio
# settings panel; Quit closes the game. Works with the mouse (hovering selects, clicking
# presses), the D-pad/stick/arrow keys and ui_accept (A, Enter, Space). ui_cancel (Escape
# or B) closes the options panel. F1 opens the room creator.

const BOOT_SCENE := "res://src/ui/menus/Boot.tscn"
const ROOM_EDITOR := "res://src/editor/RoomEditor.tscn"
const CURSOR_GAP := 32.0 # Space from the cursor's left edge to the selected option's

@onready var start_button: TextureButton = $Canvas/Start
@onready var options_button: TextureButton = $Canvas/Options
@onready var quit_button: TextureButton = $Canvas/Quit
@onready var cursor: TextureRect = $Canvas/Cursor
@onready var options_panel: OptionsPanel = $Canvas/OptionsPanel

func _ready() -> void:
	# A leftover play-test design must never make Start build someone's test room.
	Overworld.test_design = null
	for button: BaseButton in [start_button, options_button, quit_button]:
		button.focus_entered.connect(_move_cursor_to.bind(button))
		# Hovering selects, so the mouse and the controller share one highlight.
		button.mouse_entered.connect(button.grab_focus)
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(get_tree().quit)
	options_panel.back_pressed.connect(_hide_options)
	start_button.grab_focus()
	Music.play_title()
	WorldGenerator.preload_rooms() # In the background, so Start doesn't wait on them

func _unhandled_input(event: InputEvent) -> void:
	# ui_cancel covers Escape and the controller's B button, like the pause menu.
	if options_panel.visible && event.is_action_pressed("ui_cancel"):
		_hide_options()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey && event.pressed && (event as InputEventKey).keycode == KEY_F1:
		# Handled first: changing scene takes this screen out of the tree, viewport and all.
		get_viewport().set_input_as_handled()
		Music.stop_title()
		# The room creator loads enemy and tile scenes the room preload may still hold.
		WorldGenerator.finish_preload()
		get_tree().change_scene_to_file(ROOM_EDITOR)
		return
	# If focus was lost (e.g. a click on the background), the next up/down/accept
	# selects the first control of whatever screen is showing instead of doing nothing.
	if get_viewport().gui_get_focus_owner() == null && (
			event.is_action_pressed("ui_up") || event.is_action_pressed("ui_down")
			|| event.is_action_pressed("ui_accept")):
		if options_panel.visible:
			options_panel.focus_first()
		else:
			start_button.grab_focus()
		get_viewport().set_input_as_handled()

func _move_cursor_to(button: BaseButton) -> void:
	cursor.position = Vector2(button.position.x - CURSOR_GAP, button.position.y)

func _show_options() -> void:
	start_button.hide()
	options_button.hide()
	quit_button.hide()
	cursor.hide()
	options_panel.show()
	options_panel.refresh()
	options_panel.focus_first()

func _hide_options() -> void:
	options_panel.save_changes()
	options_panel.hide()
	start_button.show()
	options_button.show()
	quit_button.show()
	cursor.show()
	options_button.grab_focus()

func _on_start_pressed() -> void:
	# Stop further presses while the scene changes.
	start_button.disabled = true
	options_button.disabled = true
	quit_button.disabled = true
	Music.stop_title()
	get_tree().change_scene_to_file(BOOT_SCENE)
