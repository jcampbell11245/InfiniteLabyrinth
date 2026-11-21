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

func _ready() -> void:
	super()
	texture = HOURGLASS_TEXTURE
	_set_frames(FRAMES, FRAME_SIZE, FRAME_TIME)

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
