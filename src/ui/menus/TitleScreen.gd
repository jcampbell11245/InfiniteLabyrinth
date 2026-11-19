extends Control

# First screen on launch. Start begins a run through Boot; Options changes persistent
# music and sound-effect volume; Quit closes the game. Works with the mouse (hovering
# selects, clicking presses), the D-pad/stick/arrow keys and ui_accept (A, Enter, Space).
# F1 opens the room creator.

const BOOT_SCENE := "res://src/ui/menus/Boot.tscn"
const ROOM_EDITOR := "res://src/editor/RoomEditor.tscn"
const CURSOR_GAP := 32.0 # Space from the cursor's left edge to the selected option's
const VOLUME_PERCENT := 100.0

@onready var start_button: TextureButton = $Canvas/Start
@onready var options_button: Button = $Canvas/Options
@onready var quit_button: TextureButton = $Canvas/Quit
@onready var cursor: TextureRect = $Canvas/Cursor
@onready var options_panel: Control = $Canvas/OptionsPanel
@onready var music_slider: HSlider = $Canvas/OptionsPanel/Panel/MusicSlider
@onready var sfx_slider: HSlider = $Canvas/OptionsPanel/Panel/SfxSlider
@onready var back_button: Button = $Canvas/OptionsPanel/Panel/Back

func _ready() -> void:
	for button: BaseButton in [start_button, options_button, quit_button]:
		button.focus_entered.connect(_move_cursor_to.bind(button))
		# Hovering selects, so the mouse and the controller share one highlight.
		button.mouse_entered.connect(button.grab_focus)
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(get_tree().quit)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	back_button.pressed.connect(_hide_options)
	music_slider.value = SaveData.music_volume * VOLUME_PERCENT
	sfx_slider.value = SaveData.sfx_volume * VOLUME_PERCENT
	start_button.grab_focus()
	Music.play_title()
	WorldGenerator.preload_rooms() # In the background, so Start doesn't wait on them

func _unhandled_input(event: InputEvent) -> void:
	if options_panel.visible && event is InputEventKey && event.pressed \
			&& (event as InputEventKey).keycode == KEY_ESCAPE:
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
	# selects Start again instead of doing nothing.
	if get_viewport().gui_get_focus_owner() == null && (
			event.is_action_pressed("ui_up") || event.is_action_pressed("ui_down")
			|| event.is_action_pressed("ui_accept")):
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
	music_slider.grab_focus()

func _hide_options() -> void:
	options_panel.hide()
	start_button.show()
	options_button.show()
	quit_button.show()
	cursor.show()
	options_button.grab_focus()

func _on_music_volume_changed(value: float) -> void:
	SaveData.set_music_volume(value / VOLUME_PERCENT)
	SaveData.save()

func _on_sfx_volume_changed(value: float) -> void:
	SaveData.set_sfx_volume(value / VOLUME_PERCENT)
	SaveData.save()

func _on_start_pressed() -> void:
	# Stop further presses while the scene changes.
	start_button.disabled = true
	options_button.disabled = true
	quit_button.disabled = true
	Music.stop_title()
	get_tree().change_scene_to_file(BOOT_SCENE)
