extends SceneTree

# Saves screenshots of the running game, for checking HUD, menu and art changes without
# playing. Needs a window (not --headless: the headless renderer draws nothing):
#
#   godot --path . -s res://tools/screenshot.gd -- <output prefix> [scene] [frames]
#
# Boots `scene` (default: a fresh floor, res://src/world/Overworld.tscn), waits `frames`
# frames (default 90) and saves <output prefix>.png. Add "hurt" anywhere after the prefix
# to also take a hit then and save <prefix>_hurt_1.png and <prefix>_hurt_2.png a moment
# later, or "upgrades" to open the upgrade menu and save <prefix>_upgrades.png.
# Write the images outside the repo (a temp folder) so they don't get committed.

var _frame := 0
var _prefix := ""
var _scene := "res://src/world/Overworld.tscn"
var _frames := 90
var _hurt := false
var _upgrades := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --path . -s res://tools/screenshot.gd -- <output prefix> [scene] [frames] [hurt] [upgrades]")
		quit(2)
		return
	_prefix = args[0]
	for arg in args.slice(1):
		if arg == "hurt":
			_hurt = true
		elif arg == "upgrades":
			_upgrades = true
		elif arg.begins_with("res://"):
			_scene = arg
		elif arg.is_valid_int():
			_frames = int(arg)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		change_scene_to_file(_scene)
	elif _frame == _frames:
		_save("")
		if _hurt:
			root.get_node("Game").player.take_damage(1.0, "left", false)
		elif _upgrades:
			root.get_node("Game").upgrade_menu.show_menu()
		elif !_upgrades:
			quit()
	elif _hurt && _frame == _frames + 10:
		_save("_hurt_1")
	elif _hurt && _frame == _frames + 25:
		_save("_hurt_2")
		quit()
	elif _upgrades && _frame == _frames + 10:
		_save("_upgrades")
		quit()
	return false

func _save(suffix: String) -> void:
	var path := _prefix + suffix + ".png"
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
