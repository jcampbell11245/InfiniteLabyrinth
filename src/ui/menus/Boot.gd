extends Node2D

func _ready():
	SaveData.reset()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
