extends KinematicBody2D

export var speed : float
export var attack_speed : float
export var knockback_speed : float
export var damage : float
export var health : float
export var slash_length : int
export var attack_cooldown_length : float
var direction

var knockback = Vector2.ZERO

onready var player = get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
onready var hurtbox = $Hurtbox/CollisionShape2D
onready var invincibility_cooldown = $InvincibilityCooldown

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if animator.animation.substr(0, 5) != "slash":
		hitbox.disabled = true
	
	animate()

func _physics_process(delta):
	if(abs(player.global_position.x - global_position.x) > abs(player.global_position.y - global_position.y)):
		if(player.global_position.x - global_position.x < 0):
			direction = "left"
			$HitboxPivot.rotation_degrees = 180
		else:
			direction = "right"
			$HitboxPivot.rotation_degrees = 0
	else:
		if(player.global_position.y - global_position.y < 0):
			direction = "up"
			z_index = 10
			$HitboxPivot.rotation_degrees = 270
		else:
			direction = "down"
			z_index = 0
			$HitboxPivot.rotation_degrees = 90
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash"):
		var dir = (player.global_position - global_position).normalized()
		move_and_collide(dir * speed * delta)
	elif(attack_cooldown.time_left == 0):
		animate()
		attack()
		
	#Knockback
	knockback = knockback.move_toward(Vector2.ZERO, 200 * delta)
	knockback = move_and_slide(knockback)

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == slash_length:
		animator.animation = "idle_" + direction
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash"):
		animator.animation = "walk_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && attack_cooldown.time_left == 0):
		animator.animation = "slash_" + direction
	elif(animator.animation.substr(0, 5) != "slash"):
		animator.animation = "idle_" + direction

#Called when the enemy attacks
func attack():
	if(animator.visible == true):
		$Attack.play()
		attack_cooldown.start(attack_cooldown_length)

#Called when the enemy takes damage
func take_damage(direction):
	if(invincibility_cooldown.time_left == 0):
		hurtbox.disabled = true
		invincibility_cooldown.start(0.3)
		animator.modulate.a = 0.5
		
		var dir = Vector2.ZERO
		if(direction == "right"):
			dir = Vector2.RIGHT
		elif(direction == "left"):
			dir = Vector2.LEFT
		elif(direction == "up"):
			dir = Vector2.UP
		else:
			dir = Vector2.DOWN
		knockback = dir * knockback_speed
		
		health = health - 1
		if(health <= 0):
			die()

#Called when the enemy dies
func die():
	get_parent().death_sound(get_name())
	get_parent().remove_child(self)

func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_Hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_AnimatedSprite_frame_changed():
	if(animator.animation.substr(0, 5) == "slash" && animator.frame == attack_speed):
		hitbox.disabled = false
