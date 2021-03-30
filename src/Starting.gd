extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var floor_save = File.new()
	floor_save.open("user://floor.save", File.WRITE)
	floor_save.store_line("1")
	floor_save.close()
	
	var coins_save = File.new()
	coins_save.open("user://savefile.save", File.WRITE)
	coins_save.store_line("0")
	coins_save.close()
	
	var damage_save = File.new()
	damage_save.open("user://damage.save", File.WRITE)
	damage_save.store_line("0")
	damage_save.close()
	
	var health_save = File.new()
	health_save.open("user://health.save", File.WRITE)
	health_save.store_line("0")
	health_save.close()
	
	var looting_save = File.new()
	looting_save.open("user://looting.save", File.WRITE)
	looting_save.store_line("0")
	looting_save.close()
	
	var time_save = File.new()
	time_save.open("user://time.save", File.WRITE)
	time_save.store_line("0")
	time_save.close()
	
	get_tree().change_scene("res://src/scenes/Overworld.tscn")
