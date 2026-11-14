extends CharacterBody2D

@export var speed : float  #Speed in pixels/sec
var direction #Direction the projectile is moving
var damage #Amount of damage the projectile does
@export var rotates : bool #Whether or not the projectile rotates

func _ready():
	$ExistenceTime.start(5)

func _physics_process(_delta):
	if(!rotates && Game.player.current_room == Constants.END_ROOM):
		queue_free()
	
	#Sets projectile direction
	if(rotates):
		if(direction == "right"):
			$SpritePivot/Sprite2D.set_flip_h(true)
		elif(direction == "up"):
			$SpritePivot.rotation_degrees = 90
		elif(direction == "down"):
			$SpritePivot.rotation_degrees = 270
	
	#Moves projectile
	velocity = Direction.to_vector(direction) * speed
	move_and_slide()

#if the projectile hits anything it disappears
func _on_arrow_hitbox_area_shape_entered(area_id, area, area_shape, self_shape):
	queue_free()

func _on_existence_time_timeout():
	queue_free()

func _on_projectile_hitbox_area_entered(area):
	speed = 0
	$AnimatedSprite2D.play("break")

func _on_projectile_hitbox_body_entered(body):
	speed = 0
	$AnimatedSprite2D.play("break")

func _on_animated_sprite_2d_animation_finished():
	if($AnimatedSprite2D.animation == "break"):
		queue_free()

func _on_arrow_hitbox_body_entered(body):
	queue_free()
