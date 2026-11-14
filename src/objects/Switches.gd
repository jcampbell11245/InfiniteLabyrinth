extends Node

# Holds a room's switches. The room opens once all of them have been hit.

signal switch_hit

func _ready():
	for switch in get_children():
		switch.hit.connect(switch_hit.emit)

func unlocked():
	for switch in get_children():
		if (switch.activated == false):
			return false
	return true
