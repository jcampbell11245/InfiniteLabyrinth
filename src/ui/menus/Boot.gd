extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	var floor_save = FileAccess.open("user://floor.save", FileAccess.WRITE)
	floor_save.store_line("1")
	floor_save.close()
	
	var coins_save = FileAccess.open("user://savefile.save", FileAccess.WRITE)
	coins_save.store_line("0")
	coins_save.close()
	
	var damage_save = FileAccess.open("user://damage.save", FileAccess.WRITE)
	damage_save.store_line("0")
	damage_save.close()
	
	var health_save = FileAccess.open("user://health.save", FileAccess.WRITE)
	health_save.store_line("0")
	health_save.close()
	
	var looting_save = FileAccess.open("user://looting.save", FileAccess.WRITE)
	looting_save.store_line("0")
	looting_save.close()
	
	var time_save = FileAccess.open("user://time.save", FileAccess.WRITE)
	time_save.store_line("0")
	time_save.close()
	
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
