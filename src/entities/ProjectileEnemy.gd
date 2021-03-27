extends KinematicBody2D

export var speed : float
export var attack_speed : float
export var knockback_speed : float
export var damage : float
export var health : float
export var shoot_length : int
export var attack_cooldown_length : float
export var left_boundary : float
export var top_boundary : float
export var right_boundary : float
export var bottom_boundary : float

var direction
var knockback = Vector2.ZERO

onready var player = get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var move_cooldown = $MoveCooldown
onready var hurtbox = $Hurtbox/CollisionShape2D
onready var invincibility_cooldown = $InvincibilityCooldown

const Fireball = preload("res://src/entities/Fireball.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	animate()

func _physics_process(delta):
	if(get_parent().player_active == true):
		if(abs(player.global_position.x - global_position.x) > abs(player.global_position.y - global_position.y)):
			if(player.global_position.x - global_position.x < 0):
				direction = "left"
			else:
				direction = "right"
		else:
			if(player.global_position.y - global_position.y < 0):
				direction = "up"
				z_index = 10
			else:
				direction = "down"
				z_index = 0
		
		if((abs(player.global_position.x - global_position.x) < 25 || abs(player.global_position.y - global_position.y) < 25) && animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
			var dir = -(player.global_position - global_position).normalized()
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
	if animator.animation.substr(0, 5) == "shoot" && animator.frame == shoot_length:
		animator.animation = "idle_" + direction
	
	if((abs(player.global_position.x - global_position.x) < 25 || abs(player.global_position.y - global_position.y) < 25) && animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
		animator.animation = "walk_" + direction
	elif(animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
		animator.animation = "shoot_" + direction
	elif(animator.animation.substr(0, 5) != "shoot"):
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
	
#Returns whether or not the player is at the edge of the boundaries
func at_edge():
	if(position.x >= right_boundary || position.x <= left_boundary):
		return true
	if(position.y >= top_boundary || position.y <= bottom_boundary):
		return true
	return false

#Spawns a fireball at the enemy
func shoot_fireball():
	var fireball = Fireball.instance()
	get_parent().add_child(fireball)
	fireball.position = position
	fireball.direction = animator.animation.split("_")[1]
	fireball.damage = damage
	attack_cooldown.start(1)

func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_Hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)


func _on_AnimatedSprite_frame_changed():
	if(animator.animation.substr(0, 5) == "shoot" && animator.frame == attack_speed):
		shoot_fireball()
		$SecondShotCountdown.start(0.25)
		$ThirdShotCountdown.start(0.5)

func _on_SecondShotCountdown_timeout():
	shoot_fireball()


func _on_ThirdShotCountdown_timeout():
	shoot_fireball()
