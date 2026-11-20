extends Control
class_name PauseMenu

# Pause toggles on the pause key or the Resume button. Options opens the shared audio and
# controls settings panel; while it is open, pause, ui_cancel or Back returns to the buttons
# instead of ending the pause. The quit key exits the game while it isn't paused.

@onready var resume_button: Button = $PauseVBox/ButtonVBox/Resume
@onready var options_button: Button = $PauseVBox/ButtonVBox/Options
@onready var quit_button: Button = $PauseVBox/ButtonVBox/Quit
@onready var button_vbox: VBoxContainer = $PauseVBox/ButtonVBox
@onready var options_panel: OptionsPanel = $OptionsPanel

var pause_state := false # True while this menu has the game paused

func _ready() -> void:
	resume_button.pressed.connect(pause)
	options_button.pressed.connect(show_options)
	quit_button.pressed.connect(get_tree().quit)
	options_panel.back_pressed.connect(hide_options)

func _input(event: InputEvent) -> void:
	# Escape cancels a capture without closing the options screen or the pause menu.
	if options_panel.visible && event is InputEventKey \
			&& (event as InputEventKey).keycode == KEY_ESCAPE \
			&& options_panel.cancel_capture_if_listening():
		get_viewport().set_input_as_handled()
		return
	# While a control is being captured, the key press belongs to the rebinding UI.
	if options_panel.visible && options_panel.is_listening():
		return
	# Escape is both pause and ui_cancel, so one branch handles both without a double toggle.
	if event.is_action_pressed("pause") || event.is_action_pressed("ui_cancel"):
		if options_panel.visible:
			if !options_panel.handle_cancel():
				hide_options()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			pause()
	elif event.is_action_released("quit") && !get_tree().paused:
		get_tree().quit()

# Android's back button/gesture pauses (or unpauses) rather than closing the game; see
# application/config/quit_on_go_back. It closes the options panel first when one is open.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if options_panel.visible:
			if !options_panel.handle_cancel():
				hide_options()
		else:
			pause()

# Toggles pause, unless something else (game over, upgrade menu) has the game paused.
func pause() -> void:
	if pause_state || !get_tree().paused:
		var new_pause_state := !get_tree().paused
		get_tree().paused = new_pause_state
		visible = new_pause_state
		pause_state = new_pause_state
		_close_options()
		if new_pause_state:
			# Give the menu focus so the stick/D-pad can move between the buttons.
			resume_button.grab_focus()

func show_options() -> void:
	button_vbox.hide()
	options_panel.show()
	options_panel.refresh()
	options_panel.focus_first()

func hide_options() -> void:
	_close_options()
	options_button.grab_focus()

func _close_options() -> void:
	if options_panel.visible:
		options_panel.save_changes()
	options_panel.hide()
	button_vbox.show()
