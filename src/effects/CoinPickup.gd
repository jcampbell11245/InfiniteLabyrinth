extends "res://src/effects/Pickup.gd"

# A coin thrown out of a dying enemy. Adds `value` to Game.coins when it reaches the
# player (see Pickup for how it flies).

const COIN_TEXTURE := preload("res://assets/sprites/hud/coin.png")
# coin.png is a 2x2 sheet of 7px spin frames, as the HUD coin uses it.
const FRAMES: Array[Vector2] = [Vector2(0, 0), Vector2(7, 0), Vector2(0, 7), Vector2(7, 7)]
const FRAME_SIZE := Vector2(7, 7)
const FRAME_TIME := 0.08

var value := 0

var _frame := 0
var _frame_timer := 0.0

func _ready() -> void:
	super()
	texture = COIN_TEXTURE
	region_enabled = true
	region_rect = Rect2(FRAMES[0], FRAME_SIZE)

func _animate(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame = (_frame + 1) % FRAMES.size()
		region_rect = Rect2(FRAMES[_frame], FRAME_SIZE)

func _credit() -> void:
	Game.add_coins(value)

func _feedback() -> void:
	Juice.coin_sound()
