extends "res://tools/tests/test_case.gd"

# The F2 menu's Show FPS switch shows and hides the frames-per-second readout live.

func counter() -> CanvasLayer:
	for child in tree.root.get_children():
		if child.get_script() == preload("res://src/ui/hud/FpsCounter.gd"):
			return child as CanvasLayer
	return null

func test_show_fps_toggles_the_counter() -> void:
	await tree.process_frame
	var fps := counter()
	expect(fps != null, "debug builds add an FPS counter")
	if fps == null:
		return
	var tuning := autoload("Tuning")
	expect(!fps.visible, "the counter starts hidden")
	tuning.set_value("show_fps", true)
	expect(fps.visible, "Show FPS shows the counter")
	tuning.set_value("show_fps", false)
	expect(!fps.visible, "turning Show FPS off hides it again")
