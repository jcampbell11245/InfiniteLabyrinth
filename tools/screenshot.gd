extends SceneTree

# Saves screenshots of the running game, for checking HUD, menu and art changes without
# playing. Needs a window (not --headless: the headless renderer draws nothing):
#
#   godot --path . -s res://tools/screenshot.gd -- <output prefix> [scene] [frames]
#
# Boots `scene` (default: a fresh floor, res://src/world/Overworld.tscn), waits `frames`
# frames (default 90) and saves <output prefix>.png. Add "hurt" anywhere after the prefix
# to also take a hit then and save <prefix>_hurt_1.png and <prefix>_hurt_2.png a moment
# later, or "shop" to open the merchant's shop and save <prefix>_shop.png.
# Write the images outside the repo (a temp folder) so they don't get committed.

var _frame := 0
var _prefix := ""
var _scene := "res://src/world/Overworld.tscn"
var _frames := 90
var _hurt := false
var _shop := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --path . -s res://tools/screenshot.gd -- <output prefix> [scene] [frames] [hurt] [shop]")
		quit(2)
		return
	_prefix = args[0]
	for arg in args.slice(1):
		if arg == "hurt":
			_hurt = true
		elif arg == "shop":
			_shop = true
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
		elif _shop:
			_open_shop()
		elif !_shop:
			quit()
	elif _hurt && _frame == _frames + 10:
		_save("_hurt_1")
	elif _hurt && _frame == _frames + 25:
		_save("_hurt_2")
		quit()
	elif _shop && _frame == _frames + 10:
		_save("_shop")
		quit()
	return false

# The merchant stands in the start room (id 60); his shop is the Control under him.
func _open_shop() -> void:
	for child in root.get_node("Game").room_by_id(60).get_children():
		if child.has_method("in_reach"):
			child.find_children("*", "Control", true, false)[0].open()

func _save(suffix: String) -> void:
	var path := _prefix + suffix + ".png"
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
