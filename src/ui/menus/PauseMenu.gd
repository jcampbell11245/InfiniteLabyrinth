extends Control

var pause_state = false

func _input(event):
	if(event.is_action_pressed("pause")):
		pause()

func pause():
	if(pause_state || !get_tree().paused):
		var new_pause_state = !get_tree().paused
		get_tree().paused = new_pause_state
		visible = new_pause_state
		pause_state = new_pause_state
