extends Node

# Background music. Overworld restarts the dungeon theme on every floor; the boss theme
# plays its intro once and then switches to the loop.

@onready var dungeon: AudioStreamPlayer = $Dungeon
@onready var boss_intro: AudioStreamPlayer = $BossIntro
@onready var boss_loop: AudioStreamPlayer = $BossLoop

func start_floor() -> void:
	boss_intro.stop()
	boss_loop.stop()
	dungeon.play()

func stop_dungeon() -> void:
	dungeon.stop()

func play_boss() -> void:
	boss_intro.play()

func is_boss_playing() -> bool:
	return boss_intro.playing || boss_loop.playing

func _on_boss_intro_finished() -> void:
	if !boss_loop.playing:
		boss_loop.play()
