extends Node

# Holds a room's switches. The room opens once all of them have been hit.

signal switch_hit

func _ready() -> void:
	for switch in get_children():
		switch.hit.connect(switch_hit.emit)

func unlocked() -> bool:
	for switch in get_children():
		if !switch.activated:
			return false
	return true
