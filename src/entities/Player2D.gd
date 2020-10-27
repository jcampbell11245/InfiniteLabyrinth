extends KinematicBody2D

onready var animator = $AnimatedSprite #Player's animated sprite
onready var hurtbox = $Hurtbox/CollisionShape2D #Player's hurtbox
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D #Player's hitbox
onready var shoot_cooldown = $ShootCooldown #Cooldown to when the player can shoot again
onready var invincibility_cooldown = $InvincibilityCooldown #Cooldown to when the player can get hit again
onready var level_countdown = $LevelCountdown #Countdown for how long the player has to clear the level

var health = 10

var speed = 200  #Speed in pixels/sec

var direction = "right" #Direction the player is facing

var velocity = Vector2.ZERO #Player's velocity vector

const Arrow = preload("res://src/entities/Arrow.tscn") #Arrow tscn file

func _ready():
	level_countdown.start(5)

func _process(delta):
	control_flash()

func _physics_process(delta):
	get_input()
	animate()
	collision()
	#if ($Hurtbox.area_shape_exited()):
		#damage()
#	death()
	velocity = move_and_slide(velocity)

func get_input():
	#Movement
	velocity = Vector2.ZERO
	if(animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 5) != "shoot"):
		if Input.is_action_pressed('right'):
			velocity.x += 1
		if Input.is_action_pressed('left'):
			velocity.x -= 1
		if Input.is_action_pressed('down'):
			velocity.y += 1
		if Input.is_action_pressed('up'):
			velocity.y -= 1
		velocity = velocity.normalized() * speed
	
	#Melee Attacking
	if(Input.is_action_just_pressed("melee_attack")):
		hitbox.disabled = false;
	
	#Ranged Attacking
	if(Input.is_action_just_pressed("ranged_attack") && shoot_cooldown.time_left == 0):
		#hurtbox.disabled = true;
		var arrow = Arrow.instance()
		get_parent().add_child(arrow)
		arrow.position = position
		arrow.direction = direction
		shoot_cooldown.start(0.5)

#Animates the player
func animate():
	#Reset to idle
	if Input.is_action_just_released('right'):
		animator.animation = "idle_right"
		direction = "right"
	elif Input.is_action_just_released('left'):
		animator.animation = "idle_left"
		direction = "left"
	elif Input.is_action_just_released('down'):
		animator.animation = "idle_down"
		direction = "down"
	elif Input.is_action_just_released('up'):
		animator.animation = "idle_up"
		direction = "up"
	if animator.animation.substr(0, 5) == "slash" && animator.frame == 3:
		animator.animation = "idle_" + direction
	if animator.animation.substr(0, 5) == "shoot" && animator.frame == 2:
		animator.animation = "idle_" + direction
	
	#Movement
	if(animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 5) != "shoot"):
		if Input.is_action_pressed('right'):
			animator.animation = "walk_right"
			direction = "right"
		elif Input.is_action_pressed('left'):
			animator.animation = "walk_left"
			direction = "left"
		elif Input.is_action_pressed('down'):
			animator.animation = "walk_down"
			direction = "down"
		elif Input.is_action_pressed('up'):
			animator.animation = "walk_up"
			direction = "up"
	
	#Melee Attacking
	if(Input.is_action_just_pressed("melee_attack")):
		animator.animation = "slash_" + direction
	
	#Ranged Attacking
	if(Input.is_action_just_pressed("ranged_attack")):
		animator.animation = "shoot_" + direction

#Updates the collision boxes
func collision():
	if(direction == "right"):
		hurtbox.shape.set_extents(Vector2(11.5, 24))
		hurtbox.position = Vector2(-4.5, 0)
		$HitboxPivot.rotation_degrees = 0
	elif(direction == "left"):
		hurtbox.shape.set_extents(Vector2(11.5, 24))
		hurtbox.position = Vector2(4.5, 0)
		$HitboxPivot.rotation_degrees = 180
	elif(direction == "down"):
		hurtbox.shape.set_extents(Vector2(11.5, 24))
		hurtbox.position = Vector2(0, 0)
		$HitboxPivot.rotation_degrees = 90
	elif(direction == "up"):
		hurtbox.shape.set_extents(Vector2(11.5, 24))
		hurtbox.position = Vector2(0, 0)
		$HitboxPivot.rotation_degrees = 270
	
	if(animator.animation.substr(0, 5) != "slash"):
		hitbox.disabled = true;

#Controls flashing the character sprite during invincibility frames
func control_flash():
	#print(invincibility_cooldown.time_left)
	if(invincibility_cooldown.time_left != 0):
		if (invincibility_cooldown.time_left == 0.8):
			print("hey")
			animator.modulate(10,10,10,10) 
		elif (invincibility_cooldown.time_left == 0.6):
			animator.modulate(1,1,1,1)
		elif (invincibility_cooldown.time_left == 0.4):
			animator.modulate(10,10,10,10)
		elif (invincibility_cooldown.time_left == 0.2):
			animator.modulate(1,1,1,1)

#for timer of level running out causing death
func _on_LevelCountdown_timeout():
	get_tree().quit()

#hurtbox enetered = damage taken
func _on_Hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	invincibility_cooldown.start(1)
