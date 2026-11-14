extends Node

# Persistent progress, stored in one ConfigFile. Read the fields directly and call
# save() after changing them.

const PATH = "user://save.cfg"

var floor_number = 1
var coins = 0
var health_level = 0 # Extra hearts
var damage_level = 0 # Critical hit chance
var time_level = 0 # Extra seconds on the level timer
var looting_level = 0 # Extra coins per kill

func _ready():
	load_from_disk()

func load_from_disk():
	var file = ConfigFile.new()
	if file.load(PATH) != OK:
		return
	floor_number = file.get_value("progress", "floor", floor_number)
	coins = file.get_value("progress", "coins", coins)
	health_level = file.get_value("upgrades", "health", health_level)
	damage_level = file.get_value("upgrades", "damage", damage_level)
	time_level = file.get_value("upgrades", "time", time_level)
	looting_level = file.get_value("upgrades", "looting", looting_level)

func save():
	var file = ConfigFile.new()
	file.set_value("progress", "floor", floor_number)
	file.set_value("progress", "coins", coins)
	file.set_value("upgrades", "health", health_level)
	file.set_value("upgrades", "damage", damage_level)
	file.set_value("upgrades", "time", time_level)
	file.set_value("upgrades", "looting", looting_level)
	file.save(PATH)

func reset():
	floor_number = 1
	coins = 0
	health_level = 0
	damage_level = 0
	time_level = 0
	looting_level = 0
	save()
