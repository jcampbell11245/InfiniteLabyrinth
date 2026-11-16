extends Node2D

# Main scene: starts a new run on Tuning.start_floor (normally 1). Coins and upgrades carry
# over from the save.

func _ready() -> void:
	SaveData.floor_number = Tuning.start_floor
	SaveData.save()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
