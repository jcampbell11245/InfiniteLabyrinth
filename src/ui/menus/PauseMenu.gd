extends Control

# Pause toggles on the pause key or the Resume button. The quit key exits the game while
# it isn't paused.

var pause_state := false # True while this menu has the game paused

func _ready() -> void:
	$PauseVBox/ButtonVBox/Resume.pressed.connect(pause)
	$PauseVBox/ButtonVBox/Quit.pressed.connect(get_tree().quit)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause()
	elif event.is_action_released("quit") && !get_tree().paused:
		get_tree().quit()

# Toggles pause, unless something else (game over, upgrade menu) has the game paused.
func pause() -> void:
	if pause_state || !get_tree().paused:
		var new_pause_state := !get_tree().paused
		get_tree().paused = new_pause_state
		visible = new_pause_state
		pause_state = new_pause_state
