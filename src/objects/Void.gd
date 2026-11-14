extends Area2D

# The black cover over a room. Hidden in the editor so rooms can be edited.

func _ready() -> void:
	$ColorRect.visible = true
