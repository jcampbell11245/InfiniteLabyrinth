extends Node

# Background music. Overworld restarts the dungeon theme on every floor; the boss and
# title themes each play their intro once and then switch to their loop.

@onready var dungeon: AudioStreamPlayer = $Dungeon
@onready var boss_intro: AudioStreamPlayer = $BossIntro
@onready var boss_loop: AudioStreamPlayer = $BossLoop
@onready var title_intro: AudioStreamPlayer = $TitleIntro
@onready var title_loop: AudioStreamPlayer = $TitleLoop

func play_title() -> void:
	if !title_intro.playing && !title_loop.playing:
		title_intro.play()

func stop_title() -> void:
	title_intro.stop()
	title_loop.stop()

func start_floor() -> void:
	stop_title()
	boss_intro.stop()
	boss_loop.stop()
	dungeon.play()

func stop_dungeon() -> void:
	dungeon.stop()

# Silences every track. The players pause with the tree, so a track that is only paused
# would pick up again the moment the game unpauses.
func stop_all() -> void:
	stop_title()
	dungeon.stop()
	boss_intro.stop()
	boss_loop.stop()

# Keeps the music going while the game is paused (the merchant's greeting and shop), or
# lets it pause with the game again. Switch it on before pausing and off after unpausing,
# so the players never see the pause.
func play_through_pause(on: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT

func play_boss() -> void:
	boss_intro.play()

func is_boss_playing() -> bool:
	return boss_intro.playing || boss_loop.playing

func _on_boss_intro_finished() -> void:
	if !boss_loop.playing:
		boss_loop.play()

func _on_title_intro_finished() -> void:
	if !title_loop.playing:
		title_loop.play()
