extends Node

# Persistent progress, stored in one ConfigFile. Read the fields directly and call
# save() after changing them.

const PATH := "user://save.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const MIN_AUDIBLE_VOLUME := 0.001

var floor_number := 1
var coins := 0
var time_level := 0 # Extra seconds on the level timer
var looting_level := 0 # Extra coins per kill
var music_volume := 1.0 # Linear volume from 0 (muted) to 1 (full)
var sfx_volume := 1.0 # Linear volume from 0 (muted) to 1 (full)
# Testing aid, debug builds only: when above 0, the level timer starts at this many
# seconds instead of the upgrade-based limit. Set it by hand in the save file under
# [debug] time_limit; it survives saves and is ignored by exported release builds.
var debug_time_limit := 0
# Tests turn this off so changing a slider never overwrites the developer's save file.
var write_to_disk := true
# Testing aid: counts save attempts even when writes are disabled.
var save_calls := 0

func _ready() -> void:
	load_from_disk()
	apply_audio_settings()

func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	floor_number = file.get_value("progress", "floor", floor_number)
	coins = file.get_value("progress", "coins", coins)
	time_level = file.get_value("upgrades", "time", time_level)
	looting_level = file.get_value("upgrades", "looting", looting_level)
	music_volume = clampf(float(file.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(file.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	debug_time_limit = file.get_value("debug", "time_limit", debug_time_limit)

# Applies the saved linear sliders to their buses. Muting at zero avoids relying on a
# finite dB approximation for silence.
func apply_audio_settings() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(MUSIC_BUS, music_volume)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(SFX_BUS, sfx_volume)

func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		push_error("Missing audio bus: %s" % bus_name)
		return
	AudioServer.set_bus_mute(bus, is_zero_approx(volume))
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, MIN_AUDIBLE_VOLUME)))

func save() -> void:
	save_calls += 1
	if !write_to_disk:
		return
	var file := ConfigFile.new()
	file.set_value("progress", "floor", floor_number)
	file.set_value("progress", "coins", coins)
	file.set_value("upgrades", "time", time_level)
	file.set_value("upgrades", "looting", looting_level)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "sfx_volume", sfx_volume)
	if debug_time_limit > 0:
		file.set_value("debug", "time_limit", debug_time_limit)
	file.save(PATH)

# Clears progress only. Audio levels are a preference, so they survive a run reset.
func reset() -> void:
	floor_number = 1
	coins = 0
	time_level = 0
	looting_level = 0
	save()
