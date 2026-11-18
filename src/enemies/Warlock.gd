class_name Warlock
extends Enemy

# Warlock, the first of the wizard family. It never attacks directly: no fireballs, no
# staff. It keeps its distance, backing away from a player closer than
# Tuning.warlock_keep_away, and every so often (Tuning.warlock_curse_cooldown_min/max)
# swings its wand and puts a random curse on the player (see Curses): inverted controls,
# lowered defense, attack or speed, a daze or a jammed bow. It prefers a curse the player
# doesn't already have. Uses the wizard's body and sprites, tinted, with the cast
# animation as the wand swing, until it has art of its own.
#
# Its swing isn't an attack, so there's nothing to parry: every sword hit just lands.

const CURSE_SOUND := preload("res://assets/sfx/laser_unlock.wav")
const CURSE_PITCH := 0.6
const CURSE_COLOR := Color(0.55, 0.95, 0.35)
const WAND_TIP := Vector2(14, -14) # Where the wand's sparks fly from, before its scale

var _curse_cooldown: Timer
var _curse_sound: AudioStreamPlayer
var _engaged := false # The player is in its room; the curse cooldown is running
var _moving := false

func _ready() -> void:
	super()
	_curse_cooldown = _add_timer()
	_curse_sound = AudioStreamPlayer.new()
	_curse_sound.stream = CURSE_SOUND
	_curse_sound.volume_db = -4.0
	add_child(_curse_sound)
	direction = Direction.DOWN
	_play("idle")

func _process(_delta: float) -> void:
	if player.in_transition || is_stunned():
		_play("idle")
		return
	animate()

func _physics_process(delta: float) -> void:
	_moving = false
	if player.in_transition || !room.player_active || !is_player_in_room():
		return
	if !_engaged: # Just arrived: a full cooldown before the first curse
		_engaged = true
		_restart_cooldown()

	if !_animation_is("shoot"):
		_face_player()
		if _to_player().length() < Tuning.warlock_keep_away:
			_back_away(delta)
		elif _curse_cooldown.is_stopped():
			_play("shoot") # The wand swing; the curse lands on its attack_frame
			animator.frame = 0
	_apply_knockback(delta)

func animate() -> void:
	if _animation_is("shoot"):
		if animator.frame == attack_end_frame:
			_play("idle")
		return
	_play("walk" if _moving else "idle")

# Straight away from the player, sliding along whatever it bumps into.
func _back_away(delta: float) -> void:
	var motion := -_to_player().normalized() * speed * delta
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	_moving = true

func _face_player() -> void:
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically(0)

func _restart_cooldown() -> void:
	_curse_cooldown.start(randf_range(Tuning.warlock_curse_cooldown_min,
		maxf(Tuning.warlock_curse_cooldown_min, Tuning.warlock_curse_cooldown_max)))

func _cast_curse() -> void:
	_restart_cooldown()
	if !is_player_in_room() || !player.visible:
		return
	var effects: Array = Curses.Effect.values().filter(
		func(e: Curses.Effect) -> bool: return !player.curses.has(e))
	if effects.is_empty():
		effects = Curses.Effect.values()
	player.curses.apply(effects.pick_random())
	Juice.play(_curse_sound, 0.05, CURSE_PITCH)
	var tip := global_position + (Direction.to_vector(direction) * WAND_TIP.x + Vector2(0, WAND_TIP.y)) * scale
	Juice.burst(room, tip, CURSE_COLOR, 8, 50.0, Vector2.ZERO, 1.5, 0.3)
	Juice.burst(player.get_parent(), player.global_position, CURSE_COLOR, 14, 60.0, Vector2.ZERO, 2.0, 0.45)
	Juice.flash(player.animator, 0.2, CURSE_COLOR)

func _on_reset() -> void:
	_engaged = false
	_moving = false
	_curse_cooldown.stop()

# The wand swing isn't an attack: nothing to parry or block.
func _attack_action() -> String:
	return "shoot"

func _parry_timing() -> Parry:
	return Parry.NONE

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("shoot") && animator.frame == attack_frame:
		_cast_curse()
