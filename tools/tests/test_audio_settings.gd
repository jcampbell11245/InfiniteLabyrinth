extends "res://tools/tests/test_case.gd"

# Audio settings are saved as linear values, then applied independently to the Music and
# SFX buses so either slider can mute its category without changing the other.

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

func test_reset_keeps_audio_preferences() -> void:
	var save_data := autoload("SaveData")
	var old_write: bool = save_data.write_to_disk
	save_data.write_to_disk = false
	save_data.set_music_volume(0.2)
	save_data.set_sfx_volume(0.4)
	save_data.reset()
	expect_near(save_data.music_volume, 0.2, 0.01, "resetting progress keeps the music volume")
	expect_near(save_data.sfx_volume, 0.4, 0.01, "resetting progress keeps the SFX volume")
	save_data.set_music_volume(1.0)
	save_data.set_sfx_volume(1.0)
	save_data.write_to_disk = old_write
