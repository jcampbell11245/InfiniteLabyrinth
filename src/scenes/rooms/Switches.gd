extends Node

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

#Checks if all switches have been hit
func unlocked():
	for switch in get_children():
		if (switch.activated == false):
			return false
	return true
