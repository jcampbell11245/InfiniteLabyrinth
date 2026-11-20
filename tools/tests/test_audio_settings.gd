extends "res://tools/tests/test_case.gd"

# Audio settings are saved as linear values, then applied independently to the Music and
# SFX buses so either slider can mute its category without changing the other.

func test_slider_grabbers_use_pixel_art_icons() -> void:
	var packed := load("res://src/ui/menus/OptionsPanel.tscn") as PackedScene
	var panel := packed.instantiate() as OptionsPanel
	tree.root.add_child(panel)
	for slider: HSlider in [panel.music_slider, panel.sfx_slider]:
		expect(slider.get_theme_icon(&"grabber") != null,
			"the slider has a pixel-art grabber")
		expect(slider.get_theme_icon(&"grabber_highlight") != null,
			"the focused slider has a brighter pixel-art grabber")
	tree.root.remove_child(panel)
	panel.free()

func test_volume_controls_apply_to_their_own_buses() -> void:
	var save_data := autoload("SaveData")
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	expect(music_bus >= 0, "the Music bus exists")
	expect(sfx_bus >= 0, "the SFX bus exists")
	if music_bus < 0 || sfx_bus < 0:
		return
	save_data.set_music_volume(0.5)
	save_data.set_sfx_volume(0.25)
	expect_near(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.5), 0.01,
		"music slider sets only the Music bus")
	expect_near(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.25), 0.01,
		"sfx slider sets only the SFX bus")
	save_data.set_music_volume(0.0)
	expect(AudioServer.is_bus_mute(music_bus), "zero music volume mutes the Music bus")
	expect(!AudioServer.is_bus_mute(sfx_bus), "muting music leaves SFX audible")
	save_data.set_music_volume(1.0)
	save_data.set_sfx_volume(1.0)

func test_options_panel_saves_on_window_close_while_visible() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	var packed := load("res://src/ui/menus/OptionsPanel.tscn") as PackedScene
	var panel := packed.instantiate() as OptionsPanel
	tree.root.add_child(panel)
	var before: int = save_data.save_calls
	panel.show()
	panel.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var shown_calls: int = save_data.save_calls
	panel.hide()
	panel.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var hidden_calls: int = save_data.save_calls
	save_data.write_to_disk = old_write
	tree.root.remove_child(panel)
	panel.free()
	expect(shown_calls == before + 1, "closing the window saves while the panel is open")
	expect(hidden_calls == shown_calls, "closing the window does not save a hidden panel")

func test_reset_keeps_audio_preferences() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	# reset() clears progress in memory, which a later save would write out, so everything
	# it touches is put back afterwards (tools/run_tests.gd also restores SaveData).
	var old := {}
	for field: String in ["floor_number", "coins", "damage_level", "time_level", "looting_level",
			"music_volume", "sfx_volume"]:
		old[field] = save_data.get(field)
	save_data.write_to_disk = false
	save_data.set_music_volume(0.2)
	save_data.set_sfx_volume(0.4)
	save_data.reset()
	var music_after: float = save_data.music_volume
	var sfx_after: float = save_data.sfx_volume
	for field: String in old:
		save_data.set(field, old[field])
	save_data.apply_audio_settings()
	save_data.write_to_disk = old_write
	expect_near(music_after, 0.2, 0.01, "resetting progress keeps the music volume")
	expect_near(sfx_after, 0.4, 0.01, "resetting progress keeps the SFX volume")
