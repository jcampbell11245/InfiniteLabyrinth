extends Node

#Checks if all switches have been hit
func unlocked():
	for switch in get_children():
		if (switch.activated == false):
			return false
	return true
