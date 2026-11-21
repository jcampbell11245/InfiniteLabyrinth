extends Control
class_name PauseMenu

# Pause toggles on the pause key or the Resume button. Options opens the shared audio and
# controls settings panel; while it is open, pause, ui_cancel or Back returns to the buttons
# instead of ending the pause. Return to Title leaves the run for the title screen (or the
# room creator during a play-test); Quit to Desktop closes the game. There's deliberately
# no quit key: one stray press shouldn't end a run.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"

@onready var resume_button: Button = $PauseVBox/ButtonVBox/Resume
@onready var options_button: Button = $PauseVBox/ButtonVBox/Options
@onready var return_to_title_button: Button = $PauseVBox/ButtonVBox/ReturnToTitle
@onready var quit_to_desktop_button: Button = $PauseVBox/ButtonVBox/QuitToDesktop
@onready var button_vbox: VBoxContainer = $PauseVBox/ButtonVBox
@onready var options_panel: OptionsPanel = $OptionsPanel

var pause_state := false # True while this menu has the game paused
var _returning_to_title := false # Guards against a second press during the scene change

func _ready() -> void:
	resume_button.pressed.connect(pause)
	options_button.pressed.connect(show_options)
	return_to_title_button.pressed.connect(return_to_title)
	quit_to_desktop_button.pressed.connect(quit_to_desktop)
	options_panel.back_pressed.connect(hide_options)

func _input(event: InputEvent) -> void:
	# Escape cancels a capture except while rebinding Pause, where it binds unless held.
	# B is held by the controls panel. Neither closes the menus yet.
	if options_panel.visible && options_panel.cancel_capture_if_listening(event):
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

# The title screen needs a running tree for its music and input, and must not inherit the
# floor's pause, music or slow motion. Overworld unregisters itself when the scene changes.
func return_to_title() -> void:
	if _returning_to_title:
		return
	_returning_to_title = true
	# A room-creator play-test isn't a run. leave_test() clears Overworld.test_design (which
	# only the room editor otherwise does) and goes back to the editor instead of the title.
	if Game.overworld != null && Game.overworld.is_test():
		Game.overworld.leave_test()
		return
	get_tree().paused = false
	pause_state = false
	Juice.end_time_effects()
	Music.stop_all()
	# Coins from an unfinished floor are deliberately not banked: leaving now matches
	# quitting the game, and banking them would let a new run keep unearned loot.
	get_tree().change_scene_to_file(TITLE_SCENE)

# Closes the application from the pause menu. The title screen's Quit does the same.
func quit_to_desktop() -> void:
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
			# Give the menu focus so the stick/D-pad can reach every button.
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
