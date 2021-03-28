extends KinematicBody2D

onready var animator = $AnimatedSprite #Player's animated sprite
onready var hurtbox = $Hurtbox/CollisionShape2D #Player's hurtbox
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D #Player's hitbox
onready var shoot_cooldown = $ShootCooldown #Cooldown to when the player can shoot again
onready var invincibility_cooldown = $InvincibilityCooldown #Cooldown to when the player can get hit again
onready var level_countdown = $LevelCountdown #Countdown for how long the player has to clear the level
onready var hearts = $Camera2D/HudLayer/Hud/Hearts #Player's hearts
onready var level_countdown_text = $Camera2D/HudLayer/Hud/Timer/TimerText #The visual level countdown
onready var respawn_cooldown = $RespawnCooldown #The cooldown until the player respawns from falling in a pitfall

var respawn_x = [232, 256, 280, 304, 328, 352, 376, 400, 424]
var respawn_y = [214, 238, 262, 286, 310, 334, 358, 382, 406]

var health = 10
var speed = 125  #Speed in pixels/sec

var direction = "right" #Direction the player is facing

var velocity = Vector2.ZERO #Player's velocity vector
var knockback = Vector2.ZERO #Player's knockback vector
var last_tile = Vector2.ZERO

const Arrow = preload("res://src/entities/Arrow.tscn") #Arrow tscn file

func _ready():
	set_last_tile()
	z_index = 1

func _process(delta):
	timer()

func _physics_process(delta):
	get_input()
	animate()
	collision()
	velocity = move_and_slide(velocity)
	
	#Knockback
	knockback = knockback.move_toward(Vector2.ZERO, 300 * delta)
	knockback = move_and_slide(knockback)
	
func get_input():
	#Movement
	velocity = Vector2.ZERO
	if(animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 5) != "shoot" && $RespawnCooldown.time_left == 0):
		if Input.is_action_pressed('right'):
			set_last_tile()
			velocity.x += 1
		if Input.is_action_pressed('left'):
			set_last_tile()
			velocity.x -= 1
		if Input.is_action_pressed('down'):
			set_last_tile()
			velocity.y += 1
		if Input.is_action_pressed('up'):
			set_last_tile()
			velocity.y -= 1
		velocity = velocity.normalized() * speed
	
	#Melee Attacking
	if(Input.is_action_just_pressed("melee_attack") && animator.animation.substr(0, 5) != "slash"):
		hitbox.disabled = false;
		$Slash.play()
	
	#Ranged Attacking
	if(Input.is_action_just_pressed("ranged_attack") && shoot_cooldown.time_left == 0):
		var arrow = Arrow.instance()
		get_parent().add_child(arrow)
		arrow.position = position
		arrow.direction = direction
		shoot_cooldown.start(0.5)
		$Shoot.play()
	
	#Quitting the game
	if(Input.is_action_just_released("quit")):
		get_tree().quit()

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
	if(Input.is_action_just_pressed("melee_attack") && animator.animation.substr(0, 5) != "slash"):
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

#Method called when the player takes damage
func take_damage(damage, direction, mute):
	if(invincibility_cooldown.time_left == 0):
		invincibility_cooldown.start(1)
		animator.modulate.a = 0.5
		
		var dir = Vector2.ZERO
		if(direction == "right"):
			dir = Vector2.RIGHT
		elif(direction == "left"):
			dir = Vector2.LEFT
		elif(direction == "up"):
			dir = Vector2.UP
		elif(direction == "down"):
			dir = Vector2.DOWN
		knockback = dir * 150
		
		if(!mute):
			$Hit.play()
		
		hearts.update_health(-damage)
		if(hearts.hearts <= 0):
			die()

#Method called every frame to update the visual timer
func timer():
	level_countdown_text.set_bbcode(str(floor(level_countdown.get_time_left())))

#Method called when the player dies
func die():
	get_tree().quit()

func set_last_tile():
	var tiles = get_parent().get_child(0)
	
	var locked_x
	var locked_y
	for x in range(0, 9):
		if(respawn_x[x] > position.x):
			if(x == 0 || position.x - respawn_x[x-1] > respawn_x[x] - position.x):
				locked_x = x
			else:
				locked_x = x - 1
			break
	if(locked_x == null):
		locked_x = 8
	for y in range(0, 9):
		if(respawn_y[y] > position.y):
			if(y == 0 || position.y - respawn_y[y-1] > respawn_y[y] - position.y):
				locked_y = y
			else:
				locked_y = y - 1
			break
	if(locked_y == null):
		locked_y = 8
	
	if(tiles.get_used_cells().has(Vector2(locked_x + 9, locked_y + 9))):
		last_tile = Vector2(respawn_x[locked_x], respawn_y[locked_y])

#for timer of level running out causing death
func _on_LevelCountdown_timeout():
	die()

#hurtbox enetered = damage taken
func _on_Hurtbox_area_shape_entered(area_id, area, _area_shape, _self_shape):
	if (area.get_name() == "Hitbox" && area.get_parent().get_parent().animator.visible == true):
		direction = area.get_parent().get_parent().direction
		take_damage(area.get_parent().get_parent().damage, area.get_parent().get_parent().direction, false)
	elif(area.get_name() == "ProjectileHitbox"):
		direction = area.get_parent().direction
		take_damage(area.get_parent().damage, area.get_parent().direction, false)

#Player returns back to normal opacity once invincibility cooldown ends
func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1

#When a player hits a collision box
func _on_FeetBox_body_entered(body):
	if(respawn_cooldown.time_left == 0):
		$Fall.play()
		visible = false
		get_parent().player_active = false
		respawn_cooldown.start(1.1)


func _on_RespawnCooldown_timeout():
	visible = true
	get_parent().player_active = true
	position = last_tile
	take_damage(0.5,  "none", true)
