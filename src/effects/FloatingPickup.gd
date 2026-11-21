extends "res://src/effects/Pickup.gd"

# Shared float-then-home pickup movement. Subclasses provide the look and what happens on
# collection; this handles the brief drift around the spawn point, the bob, and the
# gentle homing toward the player.

const FLOAT_TIME := 0.8 # Seconds spent floating around before homing in
const FLOAT_SPEED := 18.0 # Pixels/sec while drifting around
const BOB_SPEED := 3.0 # Radians/sec for the hovering bob
const BOB_HEIGHT := 2.5 # Pixels moved up and down while bobbing
const HOME_ACCEL_SCALE := 0.7 # Gentler than other pickups so it feels floaty

var _bob_time := 0.0
var _float_dir := Vector2.ZERO

func _ready() -> void:
	super()
	# Pause with the game; _exit_tree still banks the pickup if the scene changes.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Start from rest so it floats out of the chest instead of popping away.
	_velocity = Vector2.ZERO
	_float_dir = Vector2.from_angle(randf() * TAU)

func _process(delta: float) -> void:
	_age += delta
	_bob_time += delta
	_animate(delta)
	offset.y = sin(_bob_time * BOB_SPEED) * BOB_HEIGHT

	var player := Game.player
	if player == null:
		_collect()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist < Tuning.pickup_collect_distance:
		_collect()
		return

	if _age < FLOAT_TIME:
		# Drift gently around the chest while leaning toward the player.
		var wander := _float_dir.rotated(sin(_bob_time * 2.0) * 0.8)
		var dir_to_player := to_player / dist if dist > 0.001 else Vector2.ZERO
		var drift := (wander + dir_to_player * 0.7).normalized() * FLOAT_SPEED
		_velocity = _velocity.move_toward(drift, FLOAT_SPEED * 3.0 * delta)
	else:
		var dir_to_player := to_player / dist
		_velocity += dir_to_player * Tuning.pickup_home_accel * HOME_ACCEL_SCALE * delta
		var speed := _velocity.length()
		if speed > 0.001:
			_velocity = _velocity.normalized().slerp(dir_to_player, 0.25) * speed
		# Don't skip past the player in a single frame.
		if speed * delta >= dist:
			global_position = player.global_position
			_collect()
			return

	global_position += _velocity * delta
	if is_instance_valid(player) && global_position.distance_to(player.global_position) < Tuning.pickup_collect_distance:
		_collect()

# Subclasses override to animate their sprite.
func _animate(_delta: float) -> void:
	pass
