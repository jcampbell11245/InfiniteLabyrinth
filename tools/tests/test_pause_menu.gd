extends "res://tools/tests/test_case.gd"

# Quitting from the pause menu, by button or quit key, leaves the run for the title screen
# without closing the game or leaving the tree paused with the floor's music playing.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"

func test_quit_button_returns_to_title() -> void:
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	menu.call("pause")
	expect(tree.paused, "the menu pauses the game")
	var quit_button := menu.get_node("PauseVBox/ButtonVBox/Quit") as Button
	quit_button.pressed.emit()
	await _scene_changed()
	expect_equal(tree.current_scene.scene_file_path, TITLE_SCENE, "the title screen is open")
	expect(!tree.paused, "the tree is running on the title screen")
	expect(autoload("Game").overworld == null, "the old floor is unregistered")
	var music := autoload("Music")
	expect(!(music.get_node("Dungeon") as AudioStreamPlayer).playing, "dungeon music stopped")
	expect((music.get_node("TitleIntro") as AudioStreamPlayer).playing ||
		(music.get_node("TitleLoop") as AudioStreamPlayer).playing, "title music playing")

func test_quit_key_returns_to_title() -> void:
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	var event := InputEventAction.new()
	event.action = "quit"
	event.pressed = false
	menu._input(event)
	await _scene_changed()
	expect_equal(tree.current_scene.scene_file_path, TITLE_SCENE, "the quit key opens the title screen")
	expect(!tree.paused, "the tree is running after the quit key")

func _scene_changed() -> void:
	for i in 5:
		await tree.process_frame
