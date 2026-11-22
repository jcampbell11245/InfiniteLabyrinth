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

func _ready() -> void:
	super()
	texture = KEY_TEXTURE
	_set_frames(FRAMES, FRAME_SIZE, FRAME_TIME)

func _credit() -> void:
	Game.add_keys(1)

func _feedback() -> void:
	# Reuse the coin pickup sound; there is no dedicated key sound yet.
	Juice.coin_sound()
