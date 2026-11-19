extends Control
class_name PauseMenu

# Pause toggles on the pause key or the Resume button. Options opens the shared audio
# settings panel; while it is open, pause or Back returns to the buttons instead of
# ending the pause. The quit key exits the game while it isn't paused.

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
	if event.is_action_pressed("pause"):
		if options_panel.visible:
			hide_options()
			get_viewport().set_input_as_handled()
		else:
			pause()
	elif event.is_action_released("quit") && !get_tree().paused:
		get_tree().quit()

# Android's back button/gesture pauses (or unpauses) rather than closing the game; see
# application/config/quit_on_go_back. It closes the options panel first when one is open.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if options_panel.visible:
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
	options_panel.hide()
	button_vbox.show()
