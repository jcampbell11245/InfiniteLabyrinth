extends "res://src/effects/Pickup.gd"

# A key released from a chest. It floats around briefly, then drifts toward the player.
# When collected it adds a key and extends the level timer.

const KEY_TEXTURE := preload("res://assets/sprites/hud/key.png")
# key.png is a 3x4 sheet of 7px frames; the HUD uses the first ten for its spin.
const FRAMES: Array[Vector2] = [
	Vector2(0, 0), Vector2(7, 0), Vector2(14, 0),
	Vector2(0, 7), Vector2(7, 7), Vector2(14, 7),
	Vector2(0, 14), Vector2(7, 14), Vector2(14, 14),
	Vector2(0, 21),
]
const FRAME_SIZE := Vector2(7, 7)
const FRAME_TIME := 0.125 # Matches the HUD key animation speed
const FLOAT_TIME := 0.8 # Seconds spent floating around before homing in
const FLOAT_SPEED := 18.0 # Pixels/sec while drifting around
const BOB_SPEED := 3.0 # Radians/sec for the hovering bob
const BOB_HEIGHT := 2.5 # Pixels moved up and down while bobbing
const HOME_ACCEL_SCALE := 0.7 # Gentler than other pickups so it feels floaty

var _bob_time := 0.0
var _float_dir := Vector2.ZERO
var _frame := 0
var _frame_timer := 0.0

func _ready() -> void:
	super()
	# Pause with the game; _exit_tree still banks the key if the scene changes.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture = KEY_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)
	# Start from rest so the key floats out of the chest instead of popping away.
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

func _animate(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)

func _credit() -> void:
	Game.add_keys(1)
	if !is_instance_valid(Game.player):
		return
	var countdown: Timer = Game.player.level_countdown
	if countdown != null && !countdown.is_stopped():
		var bonus := Tuning.key_time_bonus
		countdown.start(countdown.time_left + bonus)
		Game.time_gained.emit(bonus)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated key sound yet.
	Juice.coin_sound()
