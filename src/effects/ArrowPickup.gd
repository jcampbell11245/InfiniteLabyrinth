extends "res://src/effects/Pickup.gd"

# An arrow dropped by a dying enemy. Adds `count` to Game.arrows when it reaches the
# player (see Pickup for how it flies). Points the way it's flying.

const ARROW_TEXTURE := preload("res://assets/sprites/player/arrow_side.png") # Faces left

var count := 1

func _ready() -> void:
	super()
	texture = ARROW_TEXTURE

func _animate(_delta: float) -> void:
	if _velocity.length() > 1.0:
		rotation = _velocity.angle() + PI
	else:
		rotation += 0.15 # Spins lazily while it hangs in the air

func _credit() -> void:
	Game.add_arrows(count)

func _feedback() -> void:
	Juice.arrow_sound()
