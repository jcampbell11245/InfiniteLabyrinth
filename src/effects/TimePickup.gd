extends "res://src/effects/FloatingPickup.gd"

# An hourglass released from a chest. It floats around briefly, then drifts toward the
# player. When collected it extends the level timer.

const HOURGLASS_TEXTURE := preload("res://assets/sprites/hud/hourglass.png")
# hourglass.png is a 3x2 sheet of 11x20 frames: five frames of sand running down.
const FRAMES: Array[Vector2] = [
	Vector2(0, 0), Vector2(11, 0), Vector2(22, 0),
	Vector2(0, 20), Vector2(11, 20),
]
const FRAME_SIZE := Vector2(11, 20)
const FRAME_TIME := 0.16 # A calm sand-fall cycle

var seconds := 0.0 # Time granted on collection, set by the spawner
var _frame := 0
var _frame_timer := 0.0

func _ready() -> void:
	super()
	texture = HOURGLASS_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)

func _animate(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)

func _credit() -> void:
	if seconds <= 0.0 || !is_instance_valid(Game.player):
		return
	var countdown: Timer = Game.player.level_countdown
	if countdown != null && !countdown.is_stopped():
		countdown.start(countdown.time_left + seconds)
		Game.time_gained.emit(seconds)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated hourglass sound yet.
	Juice.coin_sound()
