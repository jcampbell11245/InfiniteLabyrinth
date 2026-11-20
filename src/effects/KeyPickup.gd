extends "res://src/effects/Pickup.gd"

# A key released from a chest. It floats around briefly, then drifts toward the player.
# When collected it adds a key and extends the level timer.

const KEY_TEXTURE := preload("res://assets/sprites/hud/key.png")
const FLOAT_TIME := 0.8 # Seconds spent floating around before homing in
const FLOAT_SPEED := 18.0 # Pixels/sec while drifting around
const BOB_SPEED := 3.0 # Radians/sec for the hovering bob
const BOB_HEIGHT := 2.5 # Pixels moved up and down while bobbing
const HOME_ACCEL_SCALE := 0.7 # Gentler than other pickups so it feels floaty

var _bob_time := 0.0
var _float_dir := Vector2.ZERO

func _ready() -> void:
	super()
	texture = KEY_TEXTURE
	# Start from rest so the key floats out of the chest instead of popping away.
	_velocity = Vector2.ZERO
	_float_dir = Vector2.from_angle(randf() * TAU)

func _process(delta: float) -> void:
	_age += delta
	_bob_time += delta
	offset.y = sin(_bob_time * BOB_SPEED) * BOB_HEIGHT

	var player := Game.player
	if player == null:
		_collect()
		return

	if _age < FLOAT_TIME:
		# Drift gently around the chest before heading to the player.
		var wander := _float_dir.rotated(sin(_bob_time * 2.0) * 0.8)
		_velocity = _velocity.move_toward(wander * FLOAT_SPEED, FLOAT_SPEED * 3.0 * delta)
	else:
		var to_player := player.global_position - global_position
		if to_player.length() < Tuning.pickup_collect_distance:
			_collect()
			return
		_velocity += to_player.normalized() * Tuning.pickup_home_accel * HOME_ACCEL_SCALE * delta
		# Turn toward the player so it glides in instead of orbiting.
		var speed := _velocity.length()
		if speed > 0.001:
			_velocity = _velocity.normalized().slerp(to_player.normalized(), 0.2) * speed

	global_position += _velocity * delta

func _credit() -> void:
	Game.add_keys(1)
	if !is_instance_valid(Game.player):
		return
	var countdown: Timer = Game.player.level_countdown
	if countdown != null && !countdown.is_stopped():
		countdown.start(countdown.time_left + Tuning.key_time_bonus)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated key sound yet.
	Juice.coin_sound()
