extends Node

# Persistent progress, stored in one ConfigFile. Read the fields directly and call
# save() after changing them.

const PATH := "user://save.cfg"

var floor_number := 1
var coins := 0
var damage_level := 0 # Critical hit chance
var time_level := 0 # Extra seconds on the level timer
var looting_level := 0 # Extra coins per kill
# Testing aid, debug builds only: when above 0, the level timer starts at this many
# seconds instead of the upgrade-based limit. Set it by hand in the save file under
# [debug] time_limit; it survives saves and is ignored by exported release builds.
var debug_time_limit := 0

func _ready() -> void:
	load_from_disk()

func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	floor_number = file.get_value("progress", "floor", floor_number)
	coins = file.get_value("progress", "coins", coins)
	damage_level = file.get_value("upgrades", "damage", damage_level)
	time_level = file.get_value("upgrades", "time", time_level)
	looting_level = file.get_value("upgrades", "looting", looting_level)
	debug_time_limit = file.get_value("debug", "time_limit", debug_time_limit)

func save() -> void:
	var file := ConfigFile.new()
	file.set_value("progress", "floor", floor_number)
	file.set_value("progress", "coins", coins)
	file.set_value("upgrades", "damage", damage_level)
	file.set_value("upgrades", "time", time_level)
	file.set_value("upgrades", "looting", looting_level)
	if debug_time_limit > 0:
		file.set_value("debug", "time_limit", debug_time_limit)
	file.save(PATH)

func reset() -> void:
	floor_number = 1
	coins = 0
	damage_level = 0
	time_level = 0
	looting_level = 0
	save()
