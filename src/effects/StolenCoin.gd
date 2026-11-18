extends Sprite2D

# A coin a troll has taken, flying from the HUD's coin icon into the troll. Only for show:
# the coins are already off Game.coins and on the troll's tally before it sets off. Homes
# like a Pickup does on the player; if the troll dies on the way it just fades out.

const COIN_TEXTURE := preload("res://assets/sprites/hud/coin.png")
const FRAMES: Array[Vector2] = [Vector2(0, 0), Vector2(7, 0), Vector2(0, 7), Vector2(7, 7)]
const FRAME_SIZE := Vector2(7, 7)
const FRAME_TIME := 0.08
const LAUNCH_SPEED := 120.0 # Pixels/sec it leaves the HUD at, in a random upward-ish direction
const HOME_ACCEL := 1100.0 # Pixels/sec² towards the troll
const ARRIVE_DISTANCE := 6.0
const FADE_TIME := 0.2
const SHRINK := 0.6 # Scale it ends at as it reaches the troll

var target: Node2D # The troll
var delay := 0.0 # Seconds hidden before setting off, so a handful don't overlap

var _velocity := Vector2.ZERO
var _frame := 0
var _frame_timer := 0.0
var _fading := false

func _ready() -> void:
	z_index = 50 # Over the room and everyone in it
	texture = COIN_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)
	visible = delay <= 0
	_velocity = Vector2.from_angle(randf_range(-PI * 0.9, -PI * 0.1)) * LAUNCH_SPEED

func _process(delta: float) -> void:
	if delay > 0:
		delay -= delta
		visible = delay <= 0
		return
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)
	if !is_instance_valid(target):
		_fade()
		global_position += _velocity * delta
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance < ARRIVE_DISTANCE:
		queue_free()
		return
	_velocity += to_target / distance * HOME_ACCEL * delta
	# Turn hard towards the troll so it doesn't orbit.
	_velocity = _velocity.normalized().slerp(to_target / distance, 0.2) * _velocity.length()
	global_position += _velocity * delta
	scale = Vector2.ONE * lerpf(SHRINK, 1.0, clampf(distance / 60.0, 0.0, 1.0))

func _fade() -> void:
	if _fading:
		return
	_fading = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
