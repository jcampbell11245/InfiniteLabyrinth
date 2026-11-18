class_name Caster
extends Enemy

# Base for the wizard family's support casters (Warlock, Necromancer): they never attack
# directly. They keep their distance, backing away from a player closer than
# Tuning.caster_keep_away, and every so often swing their staff (the wizard's cast
# animation, for now) and do something on its attack_frame: see _cast. Built on the
# wizard's body and sprites, tinted per subclass, until they have art of their own.
#
# The swing isn't an attack, so there's nothing to parry: every sword hit just lands.

const STAFF_TIP := Vector2(14, -14) # Where the staff's sparks fly from, before its scale

var _cast_cooldown: Timer
var _engaged := false # The player is in its room; the cast cooldown is running
var _moving := false

func _ready() -> void:
	super()
	_cast_cooldown = _add_timer()
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
	if is_stunned(): # Spun into (see Enemy.spin_hit)
		_apply_knockback(delta)
		return
	if !_engaged: # Just arrived: a full cooldown before the first cast
		_engaged = true
		_restart_cooldown()

	if !_animation_is("shoot"):
		_face_player()
		if _to_player().length() < Tuning.caster_keep_away:
			_back_away(delta)
		elif _cast_cooldown.is_stopped() && _can_cast():
			_play("shoot") # The staff swing; _cast runs on its attack_frame
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
	var span := _cooldown_range()
	_cast_cooldown.start(randf_range(span.x, maxf(span.x, span.y)))

# Sparks off the end of the staff in `color`.
func _staff_sparks(color: Color) -> void:
	var tip := global_position + (Direction.to_vector(direction) * STAFF_TIP.x + Vector2(0, STAFF_TIP.y)) * scale
	Juice.burst(room, tip, color, 8, 50.0, Vector2.ZERO, 1.5, 0.3)

func _on_reset() -> void:
	_engaged = false
	_moving = false
	_cast_cooldown.stop()

# The staff swing isn't an attack: nothing to parry or block.
func _attack_action() -> String:
	return "shoot"

func _parry_timing() -> Parry:
	return Parry.NONE

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("shoot") && animator.frame == attack_frame:
		_restart_cooldown()
		if is_player_in_room() && player.visible:
			_cast()

# --- For subclasses ---

# Seconds between casts, min and max, rolled each time.
func _cooldown_range() -> Vector2:
	return Vector2(3, 5)

# Whether there's any point swinging now (a necromancer with nobody to raise holds off).
func _can_cast() -> bool:
	return true

# What the swing does.
func _cast() -> void:
	pass
