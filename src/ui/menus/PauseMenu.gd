extends Control

# Pause toggles on the pause key or the Resume button. Quitting from here, by button or
# quit key, goes back to the title screen; only the title screen's Quit closes the game.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"

var pause_state := false # True while this menu has the game paused
var _returning_to_title := false # Guards against a second press during the scene change

func _ready() -> void:
	$PauseVBox/ButtonVBox/Resume.pressed.connect(pause)
	$PauseVBox/ButtonVBox/Quit.pressed.connect(return_to_title)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause()
	elif event.is_action_released("quit") && !get_tree().paused:
		return_to_title()

# The title screen needs a running tree for its music and input, and must not inherit the
# floor's pause, music or slow motion. Overworld unregisters itself when the scene changes.
func return_to_title() -> void:
	if _returning_to_title:
		return
	_returning_to_title = true
	get_tree().paused = false
	pause_state = false
	Juice.end_time_effects()
	Music.stop_all()
	get_tree().change_scene_to_file(TITLE_SCENE)

# Android's back button/gesture pauses (or unpauses) rather than closing the game; see
# application/config/quit_on_go_back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pause()

# Toggles pause, unless something else (game over, upgrade menu) has the game paused.
func pause() -> void:
	if pause_state || !get_tree().paused:
		var new_pause_state := !get_tree().paused
		get_tree().paused = new_pause_state
		visible = new_pause_state
		pause_state = new_pause_state
		if new_pause_state:
			# Give the menu focus so the stick/D-pad can move between Resume and Quit.
			$PauseVBox/ButtonVBox/Resume.grab_focus()
