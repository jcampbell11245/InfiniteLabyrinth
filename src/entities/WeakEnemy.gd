extends KinematicBody2D

var speed = 80
var direction
onready var player = get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D

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
	
	if(abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25 && animator.animation.substr(0, 5) != "slash"):
		var dir = (player.global_position - global_position).normalized()
		move_and_collide(dir * speed * delta)
	elif(attack_cooldown.time_left == 0):
		attack()

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == 3:
		animator.animation = "idle_" + direction
	
	if(abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25 && animator.animation.substr(0, 5) != "slash"):
		animator.animation = "walk_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && attack_cooldown.time_left == 0):
		animator.animation = "slash_" + direction
	elif(animator.animation.substr(0, 5) != "slash"):
		animator.animation = "idle_" + direction

#Called when the enemy attacks
func attack():
	attack_cooldown.start(1)
	hitbox.disabled = false
