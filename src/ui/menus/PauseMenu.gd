extends Control

# Pause toggles on the pause key or the Resume button. Return to Menu leaves the run for
# the title screen (or the room creator during a play-test); Quit to Desktop closes the
# game. There's deliberately no quit key: one stray press shouldn't end a run.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"

var pause_state := false # True while this menu has the game paused
var _returning_to_title := false # Guards against a second press during the scene change

func _ready() -> void:
	$PauseVBox/ButtonVBox/Resume.pressed.connect(pause)
	$PauseVBox/ButtonVBox/ReturnToMenu.pressed.connect(return_to_title)
	$PauseVBox/ButtonVBox/QuitToDesktop.pressed.connect(quit_to_desktop)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
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
			# Give the menu focus so the stick/D-pad can reach every button.
			$PauseVBox/ButtonVBox/Resume.grab_focus()
