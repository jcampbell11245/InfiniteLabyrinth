class_name Projectile
extends CharacterBody2D

# A straight-flying shot: the player's arrows, wizard fireballs and boss lasers. Set
# `direction` and `damage` after instancing it. The player reads `damage` and `direction`
# when a ProjectileHitbox touches it.

const LIFETIME := 5.0
const SPAWN_MARGIN := 5.0 # Distance from walls to keep the spawn point, covering the hitbox

@export var speed: float # Pixels/sec
@export var rotates: bool # Turn the sprite to face `direction` (art faces left)
@export var rotate_hitbox: bool # Turn the hitbox with the sprite
@export var breaks_on_hit: bool # Stop and play "break" on impact instead of vanishing
@export var free_in_end_room: bool # Vanish once the player reaches the end room
@export var impact_color := Color(0.85, 0.75, 0.55) # Splinters or sparks sprayed on impact

var direction := "": set = _set_direction
var damage: float
var _hit := false # Impact effects play once, though area and body signals can both fire

func _ready() -> void:
	$ExistenceTime.start(LIFETIME)

func _physics_process(_delta: float) -> void:
	if free_in_end_room && Game.player.current_room == Constants.END_ROOM:
		queue_free()
	
	velocity = Direction.to_vector(direction) * speed
	move_and_slide()

func _set_direction(value: String) -> void:
	direction = value
	if !rotates:
		return
	var degrees := 0.0
	match direction:
		Direction.RIGHT: $SpritePivot/Sprite2D.flip_h = true
		Direction.UP: degrees = 90.0
		Direction.DOWN: degrees = 270.0
	$SpritePivot.rotation_degrees = degrees
	if rotate_hitbox:
		$ProjectileHitbox.rotation_degrees = degrees

func _on_hitbox_hit(_area_or_body: Node2D) -> void:
	if !_hit:
		_hit = true
		Juice.burst(get_parent(), global_position, impact_color, 6, 60.0,
			-Direction.to_vector(direction), 1.5, 0.25)
	if breaks_on_hit:
		speed = 0
		$AnimatedSprite2D.play("break")
	else:
		queue_free()

func _on_existence_time_timeout() -> void:
	queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "break":
		queue_free()
