extends Node

# Background music. Overworld restarts the dungeon theme on every floor; the boss theme
# plays its intro once and then switches to the loop.

@onready var dungeon = $Dungeon
@onready var boss_intro = $BossIntro
@onready var boss_loop = $BossLoop

func start_floor():
	boss_intro.stop()
	boss_loop.stop()
	dungeon.play()

func stop_dungeon():
	dungeon.stop()

func play_boss():
	boss_intro.play()

func is_boss_playing():
	return boss_intro.playing || boss_loop.playing

func _on_boss_intro_finished():
	if(!boss_loop.playing):
		boss_loop.play()
