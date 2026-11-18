extends Control

# First screen on launch. Start begins a run through Boot; Quit closes the game. Works
# with the mouse (hovering selects, clicking presses), the D-pad/stick/arrow keys
# (ui_up/ui_down move between options) and ui_accept (A, Enter, Space) to press.
# F1 opens the room creator.

const BOOT_SCENE := "res://src/ui/menus/Boot.tscn"
const ROOM_EDITOR := "res://src/editor/RoomEditor.tscn"
const CURSOR_GAP := 32.0 # Space from the cursor's left edge to the selected option's

@onready var start_button: TextureButton = $Canvas/Start
@onready var quit_button: TextureButton = $Canvas/Quit
@onready var cursor: TextureRect = $Canvas/Cursor

func _ready() -> void:
	for button: TextureButton in [start_button, quit_button]:
		button.focus_entered.connect(_move_cursor_to.bind(button))
		# Hovering selects, so the mouse and the controller share one highlight.
		button.mouse_entered.connect(button.grab_focus)
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(get_tree().quit)
	start_button.grab_focus()
	Music.play_title()
	WorldGenerator.preload_rooms() # In the background, so Start doesn't wait on them

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey && event.pressed && (event as InputEventKey).keycode == KEY_F1:
		# Handled first: changing scene takes this screen out of the tree, viewport and all.
		get_viewport().set_input_as_handled()
		Music.stop_title()
		get_tree().change_scene_to_file(ROOM_EDITOR)
		return
	# If focus was lost (e.g. a click on the background), the next up/down/accept
	# selects Start again instead of doing nothing.
	if get_viewport().gui_get_focus_owner() == null && (
			event.is_action_pressed("ui_up") || event.is_action_pressed("ui_down")
			|| event.is_action_pressed("ui_accept")):
		start_button.grab_focus()
		get_viewport().set_input_as_handled()

func _move_cursor_to(button: TextureButton) -> void:
	cursor.position = Vector2(button.position.x - CURSOR_GAP, button.position.y)

func _on_start_pressed() -> void:
	# Stop further presses while the scene changes.
	start_button.disabled = true
	quit_button.disabled = true
	Music.stop_title()
	get_tree().change_scene_to_file(BOOT_SCENE)
