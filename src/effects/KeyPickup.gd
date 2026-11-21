extends "res://src/effects/FloatingPickup.gd"

# A key released from a chest. It floats around briefly, then drifts toward the player.
# When collected it adds a key.

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

var _frame := 0
var _frame_timer := 0.0

func _ready() -> void:
	super()
	texture = KEY_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)

func _animate(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)

func _credit() -> void:
	Game.add_keys(1)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated key sound yet.
	Juice.coin_sound()
