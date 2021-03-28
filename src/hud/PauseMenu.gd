extends Control

func _input(event):
	if(event.is_action_pressed("pause")):
		pause()

func pause():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
