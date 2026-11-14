extends CharacterBody2D

# A straight-flying shot: the player's arrows, wizard fireballs and boss lasers. Set
# `direction` and `damage` after instancing it. The player reads `damage` and `direction`
# when a ProjectileHitbox touches it.

const LIFETIME = 5.0

@export var speed : float # Pixels/sec
@export var rotates : bool # Turn the sprite to face `direction` (art faces left)
@export var rotate_hitbox : bool # Turn the hitbox with the sprite
@export var breaks_on_hit : bool # Stop and play "break" on impact instead of vanishing
@export var free_in_end_room : bool # Vanish once the player reaches the end room

var direction : set = _set_direction
var damage

func _ready():
	$ExistenceTime.start(LIFETIME)

func _physics_process(_delta):
	if(free_in_end_room && Game.player.current_room == Constants.END_ROOM):
		queue_free()

	velocity = Direction.to_vector(direction) * speed
	move_and_slide()

func _set_direction(value):
	direction = value
	if(!rotates):
		return
	var degrees = 0.0
	match direction:
		Direction.RIGHT: $SpritePivot/Sprite2D.flip_h = true
		Direction.UP: degrees = 90.0
		Direction.DOWN: degrees = 270.0
	$SpritePivot.rotation_degrees = degrees
	if(rotate_hitbox):
		$ProjectileHitbox.rotation_degrees = degrees

func _on_hitbox_hit(_area_or_body):
	if(breaks_on_hit):
		speed = 0
		$AnimatedSprite2D.play("break")
	else:
		queue_free()

func _on_existence_time_timeout():
	queue_free()

func _on_animated_sprite_2d_animation_finished():
	if($AnimatedSprite2D.animation == "break"):
		queue_free()
