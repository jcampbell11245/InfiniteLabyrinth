extends SceneTree

# Remakes the inner wall sheet the game draws with (InnerWalls.JOINED) from the hand-drawn
# one (InnerWalls.SOURCE), adding the inside-corner pieces. Run it after changing the
# hand-drawn sheet, then import:
#
#   godot --headless --path . -s res://tools/build_inner_walls.gd
#   godot --headless --path . --import

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(InnerWalls.SOURCE))
	var joined := InnerWalls.build_image(source)
	var error := joined.save_png(ProjectSettings.globalize_path(InnerWalls.JOINED))
	if error != OK:
		push_error("Couldn't save %s: %s" % [InnerWalls.JOINED, error_string(error)])
	else:
		print("Saved %s (%d pieces)" % [InnerWalls.JOINED, 16 + InnerWalls.extras().size()])
	quit(error)
