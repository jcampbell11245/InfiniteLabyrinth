extends Node2D

# Main scene: wipes the save (see BUGS.md) and starts the first floor.

func _ready() -> void:
	SaveData.reset()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
