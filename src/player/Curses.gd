class_name Curses
extends Node

# Status effects a warlock puts on the player, each lasting Tuning.curse_duration (daze is
# shorter, Tuning.curse_daze_time, and uses the player's own daze). The player reads these
# as it moves, attacks and takes hits; each running curse shows as an icon and a bar over
# the player's head (see Player._add_status_bars).
#
#   INVERTED      left is right and up is down
#   DEFENSE_DOWN  hits taken do Tuning.curse_defense_multiplier times the damage
#   ATTACK_DOWN   sword and arrows do Tuning.curse_attack_multiplier times the damage
#   SLOW          walking and rolling at Tuning.curse_speed_multiplier times the speed
#   DAZE          can't act at all, like being blocked (no extra damage taken, though)
#   JAM           the bow won't draw; pressing shoot just clicks

enum Effect { INVERTED, DEFENSE_DOWN, ATTACK_DOWN, SLOW, DAZE, JAM }

const JAM_SOUND := preload("res://assets/sfx/clank_bad.wav")

var player: Player
var _timers := {} # Effect -> Timer, for every effect but DAZE
var _jam_sound: AudioStreamPlayer

func _ready() -> void:
	for effect: Effect in [Effect.INVERTED, Effect.DEFENSE_DOWN, Effect.ATTACK_DOWN, Effect.SLOW, Effect.JAM]:
		var timer := Timer.new()
		timer.one_shot = true
		add_child(timer)
		_timers[effect] = timer
	_jam_sound = AudioStreamPlayer.new()
	_jam_sound.bus = &"SFX"
	_jam_sound.stream = JAM_SOUND
	_jam_sound.volume_db = -8.0
	add_child(_jam_sound)

# Puts `effect` on the player, restarting it if it's already running.
func apply(effect: Effect) -> void:
	if effect == Effect.DAZE:
		player.daze(Tuning.curse_daze_time)
	else:
		(_timers[effect] as Timer).start(Tuning.curse_duration)

func has(effect: Effect) -> bool:
	if effect == Effect.DAZE:
		return player.is_dazed()
	return !(_timers[effect] as Timer).is_stopped()

# For a status bar: how much of the curse is left, 1 to 0.
func left(effect: Effect) -> float:
	return StatusBars.timer_left(_timers[effect])

func clear() -> void:
	for timer: Timer in _timers.values():
		timer.stop()

func damage_taken_multiplier() -> float:
	return Tuning.curse_defense_multiplier if has(Effect.DEFENSE_DOWN) else 1.0

func damage_dealt_multiplier() -> float:
	return Tuning.curse_attack_multiplier if has(Effect.ATTACK_DOWN) else 1.0

func speed_multiplier() -> float:
	return Tuning.curse_speed_multiplier if has(Effect.SLOW) else 1.0

# The direction pressed, swapped for its opposite while INVERTED.
func steer(dir: String) -> String:
	if !has(Effect.INVERTED):
		return dir
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return dir

# Tried to shoot while JAM is on: a dull click and a puff of smoke from the bow.
func jam_feedback() -> void:
	Juice.play(_jam_sound, 0.06, 1.6)
	var aim := Direction.to_vector(player.direction)
	Juice.burst(player.get_parent(), player.global_position + aim * 8, Color(0.5, 0.5, 0.5), 5, 30.0,
		aim, 1.5, 0.3)
