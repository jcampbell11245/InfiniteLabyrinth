extends Sprite2D

# A coin thrown out of a dying enemy. It pops outward, hangs for a moment, then homes in
# on the player and adds `value` to Game.coins when it arrives. Runs while paused so a
# coin in flight when the player dies still gets banked before the floor resets.

const COIN_TEXTURE := preload("res://assets/sprites/hud/coin.png")
# coin.png is a 2x2 sheet of 7px spin frames, as the HUD coin uses it.
const FRAMES: Array[Vector2] = [Vector2(0, 0), Vector2(7, 0), Vector2(0, 7), Vector2(7, 7)]
const FRAME_SIZE := Vector2(7, 7)
const FRAME_TIME := 0.08
const POP_SPEED := 70.0 # Pixels/sec outward at the start
const POP_TIME := 0.3 # Seconds before it starts homing
const HOME_ACCEL := 900.0 # Pixels/sec² towards the player
const COLLECT_DISTANCE := 6.0

var value := 0

var _velocity := Vector2.ZERO
var _age := 0.0
var _credited := false
var _frame := 0
var _frame_timer := 0.0

func _ready() -> void:
	texture = COIN_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)
	z_index = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velocity = Vector2.from_angle(randf() * TAU) * POP_SPEED * randf_range(0.6, 1.0)

func _process(delta: float) -> void:
	_age += delta
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)
	var player := Game.player
	if player == null:
		_collect()
		return
	if _age < POP_TIME:
		_velocity = _velocity.move_toward(Vector2.ZERO, POP_SPEED * 2.5 * delta)
	else:
		var to_player := player.global_position - global_position
		if to_player.length() < COLLECT_DISTANCE:
			_collect()
			return
		_velocity += to_player.normalized() * HOME_ACCEL * delta
		# Turn hard towards the player so it doesn't orbit.
		_velocity = _velocity.normalized().slerp(to_player.normalized(), 0.25) * _velocity.length()
	global_position += _velocity * delta

func _collect() -> void:
	if !_credited:
		_credited = true
		Game.add_coins(value)
	queue_free()

# Never lose coins: if the coin is removed before it arrives (scene change), bank it.
func _exit_tree() -> void:
	if !_credited:
		_credited = true
		Game.add_coins(value)
