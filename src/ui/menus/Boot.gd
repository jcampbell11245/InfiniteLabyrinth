extends Node2D

# Main scene: starts a new run on floor 1. Coins and upgrades carry over from the save.

func _ready() -> void:
	SaveData.floor_number = 1
	SaveData.save()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
