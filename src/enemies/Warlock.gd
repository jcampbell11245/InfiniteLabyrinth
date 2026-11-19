class_name Warlock
extends Caster

# Warlock, of the wizard family: keeps its distance (see Caster) and every
# Tuning.warlock_curse_cooldown_min/max seconds swings its staff to put a random curse on
# the player (see Curses): inverted controls, lowered defense, attack or speed, a daze or a
# jammed bow. It prefers a curse the player doesn't already have.

const CURSE_SOUND := preload("res://assets/sfx/laser_unlock.wav")
const CURSE_PITCH := 0.6
const CURSE_COLOR := Color(0.55, 0.95, 0.35)

var _curse_sound: AudioStreamPlayer

func _ready() -> void:
	super()
	_curse_sound = AudioStreamPlayer.new()
	_curse_sound.bus = &"SFX"
	_curse_sound.stream = CURSE_SOUND
	_curse_sound.volume_db = -4.0
	add_child(_curse_sound)

func _cooldown_range() -> Vector2:
	return Vector2(Tuning.warlock_curse_cooldown_min, Tuning.warlock_curse_cooldown_max)

func _cast() -> void:
	var effects: Array = Curses.Effect.values().filter(
		func(e: Curses.Effect) -> bool: return !player.curses.has(e))
	if effects.is_empty():
		effects = Curses.Effect.values()
	player.curses.apply(effects.pick_random())
	Juice.play(_curse_sound, 0.05, CURSE_PITCH)
	_staff_sparks(CURSE_COLOR)
	Juice.burst(player.get_parent(), player.global_position, CURSE_COLOR, 14, 60.0, Vector2.ZERO, 2.0, 0.45)
	Juice.flash(player.animator, 0.2, CURSE_COLOR)
