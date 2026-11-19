extends "res://tools/tests/test_case.gd"

# The pause menu's Return to Menu button and quit key leave the run for the title screen
# without closing the game; its Quit to Desktop button closes the application.

const TITLE_SCENE := "res://src/ui/menus/TitleScreen.tscn"

func test_return_to_menu_button_returns_to_title() -> void:
	await boot_floor()
	var menu := tree.current_scene.get_node("PauseLayer/Pause")
	menu.call("pause")
	expect(tree.paused, "the menu pauses the game")
	var menu_button := menu.get_node("PauseVBox/ButtonVBox/ReturnToMenu") as Button
	expect_equal(menu_button.text, "Return to Menu", "the button says Return to Menu")
	menu_button.pressed.emit()
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

func test_quit_to_desktop_button_is_wired_to_quit() -> void:
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
