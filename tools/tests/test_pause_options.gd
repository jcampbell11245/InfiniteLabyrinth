extends "res://tools/tests/test_case.gd"

# The pause menu uses the same audio settings panel as the title screen. Opening it must
# leave the run paused, and the pause key must close the panel before it resumes the game.

func test_pause_menu_has_shared_options_panel() -> void:
	var menu := _add_pause_menu()
	expect(menu != null, "the pause menu scene loads")
	if menu == null:
		return
	expect(menu.options_panel is OptionsPanel, "the pause menu reuses the OptionsPanel scene")
	expect(menu.get_node("PauseVBox/ButtonVBox/Options") is Button, "the pause menu has an Options button")
	_free_menu(menu)

func test_options_panel_changes_settings_and_returns_to_buttons() -> void:
	var save_data := autoload("SaveData")
	var old_music: float = save_data.music_volume
	var old_sfx: float = save_data.sfx_volume
	var menu := _add_pause_menu()
	if menu == null:
		return
	save_data.set_music_volume(0.3)
	save_data.set_sfx_volume(0.7)
	menu.show_options()
	expect(menu.options_panel.visible, "Options shows the panel")
	expect(!menu.get_node("PauseVBox/ButtonVBox").visible, "Options hides the pause buttons")
	expect_near(menu.options_panel.music_slider.value, 30.0, 0.01, "the music slider shows the saved value")
	menu.options_panel.sfx_slider.value = 25.0
	expect_near(save_data.sfx_volume, 0.25, 0.01, "the panel writes the SFX volume through SaveData")
	menu.options_panel.back_pressed.emit()
	expect(!menu.options_panel.visible, "Back closes the panel")
	expect(menu.get_node("PauseVBox/ButtonVBox").visible, "Back restores the pause buttons")
	save_data.set_music_volume(old_music)
	save_data.set_sfx_volume(old_sfx)
	save_data.save()
	_free_menu(menu)

func test_pause_key_closes_options_before_resuming() -> void:
	var menu := _add_pause_menu()
	if menu == null:
		return
	menu.pause()
	expect(tree.paused, "pausing opens the menu")
	menu.show_options()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	expect(!menu.options_panel.visible, "pause closes the options panel first")
	expect(tree.paused, "closing the options panel leaves the game paused")
	expect(menu.visible, "the pause menu is still open")
	menu._input(escape)
	expect(!tree.paused, "a second pause press resumes the game")
	expect(!menu.visible, "the pause menu hides on resume")
	_free_menu(menu)

func _add_pause_menu() -> PauseMenu:
	var packed := load("res://src/ui/menus/PauseMenu.tscn") as PackedScene
	if packed == null:
		return null
	var layer := packed.instantiate() as CanvasLayer
	tree.root.add_child(layer)
	return layer.get_node("Pause") as PauseMenu

func _free_menu(menu: PauseMenu) -> void:
	var layer := menu.get_parent()
	tree.root.remove_child(layer)
	layer.free()
