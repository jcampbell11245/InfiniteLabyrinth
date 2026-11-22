extends "res://tools/tests/test_case.gd"

# The pause menu uses the same audio settings panel as the title screen. Opening it must
# leave the run paused, and the pause/cancel keys must close the panel before resuming.

func test_pause_menu_has_shared_options_panel() -> void:
	var menu := _add_pause_menu()
	expect(menu != null, "the pause menu scene loads")
	if menu == null:
		return
	expect(menu.options_panel is OptionsPanel, "the pause menu reuses the OptionsPanel scene")
	expect(menu.get_node("PauseVBox/ButtonVBox/Options") is Button, "the pause menu has an Options button")
	_free_menu(menu)

func test_pause_options_panel_is_large_and_centred() -> void:
	var menu := _add_pause_menu()
	if menu == null:
		return
	var panel := menu.options_panel
	expect_near(panel.anchor_left, 0.5, 0.001, "the panel is anchored to the pause menu's centre")
	expect_near(panel.anchor_top, 0.5, 0.001, "the panel is vertically centred")
	expect_near(panel.offset_right - panel.offset_left, 704.0, 0.01,
		"the panel keeps the title screen's layout size")
	expect_near(panel.scale.x, 2.72727, 0.001, "the panel is scaled up to match the title screen")
	expect_near(panel.pivot_offset.x, (panel.offset_right - panel.offset_left) / 2.0, 0.01,
		"the panel scales around its centre")
	_free_menu(menu)

func test_options_panel_changes_settings_and_returns_to_buttons() -> void:
	var save_data := autoload("SaveData")
	var old_music: float = save_data.music_volume
	var old_sfx: float = save_data.sfx_volume
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var menu := _add_pause_menu()
	if menu == null:
		save_data.write_to_disk = old_write
		return
	save_data.set_music_volume(0.3)
	save_data.set_sfx_volume(0.7)
	menu.show_options()
	var shown: bool = menu.options_panel.visible
	var buttons_hidden: bool = !menu.get_node("PauseVBox/ButtonVBox").visible
	var shown_music: float = menu.options_panel.music_slider.value
	menu.options_panel.sfx_slider.value = 25.0
	var sfx_after: float = save_data.sfx_volume
	menu.options_panel.back_pressed.emit()
	var closed: bool = !menu.options_panel.visible
	var buttons_shown: bool = menu.get_node("PauseVBox/ButtonVBox").visible
	# Restore before checking anything so a failed expectation can't leave the real
	# volumes or save behaviour changed.
	save_data.set_music_volume(old_music)
	save_data.set_sfx_volume(old_sfx)
	save_data.write_to_disk = old_write
	_free_menu(menu)
	expect(shown, "Options shows the panel")
	expect(buttons_hidden, "Options hides the pause buttons")
	expect_near(shown_music, 30.0, 0.01, "the music slider shows the saved value")
	expect_near(sfx_after, 0.25, 0.01, "the panel writes the SFX volume through SaveData")
	expect(closed, "Back closes the panel")
	expect(buttons_shown, "Back restores the pause buttons")

func test_pause_key_closes_options_before_resuming() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var menu := _add_pause_menu()
	if menu == null:
		save_data.write_to_disk = old_write
		return
	menu.pause()
	expect(tree.paused, "pausing opens the menu")
	menu.show_options()
	var bindings := autoload("Bindings")
	var pause := InputEventKey.new()
	pause.keycode = int(bindings.key_for("pause"))
	pause.pressed = true
	menu._input(pause)
	expect(!menu.options_panel.visible, "pause closes the options panel first")
	expect(tree.paused, "closing the options panel leaves the game paused")
	expect(menu.visible, "the pause menu is still open")
	menu._input(pause)
	expect(!tree.paused, "a second pause press resumes the game")
	expect(!menu.visible, "the pause menu hides on resume")
	save_data.write_to_disk = old_write
	_free_menu(menu)

func test_ui_cancel_closes_options_without_resuming() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var menu := _add_pause_menu()
	if menu == null:
		save_data.write_to_disk = old_write
		return
	menu.pause()
	menu.show_options()
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	menu._input(back)
	expect(!menu.options_panel.visible, "the controller's cancel button closes the options panel")
	expect(tree.paused, "closing options with cancel leaves the game paused")
	expect(menu.visible, "the pause menu stays open after cancel")
	save_data.write_to_disk = old_write
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
