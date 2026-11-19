extends "res://tools/tests/test_case.gd"

# The pause menu's Return to Title button leaves the run for the title screen, or the room
# creator during a play-test; its Quit to Desktop button closes the application.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"
const ROOM_EDITOR := "res://src/editor/RoomEditor.tscn"

func test_return_to_title_button_returns_to_title() -> void:
	Overworld.test_design = null
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	menu.call("pause")
	expect(tree.paused, "the menu pauses the game")
	var menu_button := menu.get_node("PauseVBox/ButtonVBox/ReturnToTitle") as Button
	expect_equal(menu_button.text, "Return to Title", "the button says Return to Title")
	menu_button.pressed.emit()
	await _scene_changed()
	expect_equal(tree.current_scene.scene_file_path, TITLE_SCENE, "the title screen is open")
	expect(!tree.paused, "the tree is running on the title screen")
	expect(autoload("Game").overworld == null, "the old floor is unregistered")
	var music := autoload("Music")
	expect(!(music.get_node("Dungeon") as AudioStreamPlayer).playing, "dungeon music stopped")
	expect((music.get_node("TitleIntro") as AudioStreamPlayer).playing ||
		(music.get_node("TitleLoop") as AudioStreamPlayer).playing, "title music playing")

func test_return_to_title_from_play_test_goes_to_room_editor() -> void:
	Overworld.test_design = RoomDesign.new()
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	menu.call("pause")
	var menu_button := menu.get_node("PauseVBox/ButtonVBox/ReturnToTitle") as Button
	menu_button.pressed.emit()
	await _scene_changed()
	expect_equal(tree.current_scene.scene_file_path, ROOM_EDITOR,
		"a play-test goes back to the room creator")
	expect(Overworld.test_design == null, "the play-test design is cleared")
	expect(!tree.paused, "the tree is running in the room creator")

func test_leaving_play_test_ends_time_effects() -> void:
	Overworld.test_design = RoomDesign.new()
	await boot_floor()
	var juice := autoload("Juice")
	juice.slow_motion(0.1)
	expect(Engine.time_scale < Tuning.game_speed, "slow motion is active in the play-test")
	autoload("Game").overworld.leave_test()
	await _scene_changed()
	expect_near(Engine.time_scale, Tuning.game_speed, 0.001,
		"leaving a play-test restores normal speed")

func test_title_screen_clears_a_stale_play_test_design() -> void:
	Overworld.test_design = RoomDesign.new()
	tree.change_scene_to_file(TITLE_SCENE)
	await _scene_changed()
	expect(Overworld.test_design == null, "Start won't build a leftover test room")

func test_quit_to_desktop_button_is_wired_to_quit() -> void:
	Overworld.test_design = null
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	var desktop_button := menu.get_node("PauseVBox/ButtonVBox/QuitToDesktop") as Button
	expect(desktop_button != null, "the pause menu has a Quit to Desktop button")
	if desktop_button == null:
		return
	expect_equal(desktop_button.text, "Quit to Desktop", "the button says Quit to Desktop")
	expect(menu.has_method("quit_to_desktop"), "the menu has a desktop quit handler")
	var wired := false
	for connection: Dictionary in desktop_button.pressed.get_connections():
		var callable: Callable = connection.callable
		if callable.get_object() == menu && callable.get_method() == "quit_to_desktop":
			wired = true
	expect(wired, "the button's pressed signal calls quit_to_desktop")

func _scene_changed() -> void:
	for i in 5:
		await tree.process_frame
