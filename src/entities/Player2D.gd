extends KinematicBody2D

onready var animator = $AnimatedSprite #Player's animated sprite
onready var hurtbox = $Hurtbox/CollisionShape2D #Player's hurtbox
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D #Player's hitbox
onready var shoot_cooldown = $ShootCooldown #Cooldown to when the player can shoot again
onready var invincibility_cooldown = $InvincibilityCooldown #Cooldown to when the player can get hit again
onready var level_countdown = $LevelCountdown #Countdown for how long the player has to clear the level
onready var respawn_cooldown = $RespawnCooldown #The cooldown until the player respawns from falling in a pitfall
onready var hearts = get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Hearts") #Player's hearts
onready var level_countdown_text = get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Timer/TimerText") #The visual level countdown

var respawn_x = [304, 328, 352, 376, 400, 424, 448, 472, 496]
var respawn_y = [46, 70, 94, 118, 142, 166, 190, 214, 238]

var health = 10 #Player's health
var speed = 125  #Speed in pixels/sec
var current_room = 0

var direction = "right" #Direction the player is facing

var velocity = Vector2.ZERO #Player's velocity vector
var knockback = Vector2.ZERO #Player's knockback vector
var last_tile = Vector2.ZERO
var last_velocity = Vector2.ZERO

var transitioning = false
var transitioned = false

const Arrow = preload("res://src/entities/Arrow.tscn") #Arrow tscn file

func _ready():
	$DungeonMusic.play()
	z_index = 2

func _process(delta):
	#if(current_room == 62 && !$BossMusic.playing && !$BossMusicLoop.playing):
	#	$DungeonMusic.stop()
	#	$BossMusic.play()
	
	#print(current_room)
	timer()

func _physics_process(delta):
	if(!transitioning):
		get_input()
		animate()
		collision()
	if(visible):
		velocity = move_and_slide(velocity)
	
	#Knockback
	knockback = knockback.move_toward(Vector2.ZERO, 300 * delta)
	knockback = move_and_slide(knockback)
	
	set_last_tile()
	
func get_input():
	#Movement
	velocity = Vector2.ZERO
	if(animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 5) != "shoot" && animator.animation.substr(0, 6) != "damage" && $RespawnCooldown.time_left == 0):
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
	if(Input.is_action_just_pressed("melee_attack") && animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 6) != "damage"):
		hitbox.disabled = false;
		$Slash.play()
	
	#Ranged Attacking
	if(Input.is_action_just_pressed("ranged_attack") && animator.animation.substr(0, 6) != "damage" && shoot_cooldown.time_left == 0):
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
	if animator.animation.substr(0, 5) == "slash" && animator.frame == 7:
		animator.animation = "idle_" + direction
	if animator.animation.substr(0, 5) == "shoot" && animator.frame == 1:
		animator.animation = "idle_" + direction
	if animator.animation.substr(0, 6) == "damage" && animator.frame == 4:
		animator.animation = "idle_" + direction
	
	#Movement
	if(animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 5) != "shoot" && animator.animation.substr(0, 6) != "damage" && animator.animation.substr(0, 9) != "walkshoot"):
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
	if(Input.is_action_just_pressed("melee_attack") && animator.animation.substr(0, 5) != "slash" && animator.animation.substr(0, 6) != "damage"):
		animator.animation = "slash_" + direction
	
	#Ranged Attacking
	if(Input.is_action_just_pressed("ranged_attack") && animator.animation.substr(0, 6) != "damage"):
		if(animator.animation.substr(0, 4) == "walk"):
			animator.animation = "walkshoot_" + direction
		elif(animator.animation):
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
		
		animator.animation = "damage_" + direction
		
		var dir = Vector2.ZERO
		if(direction == "right"):
			dir = Vector2.RIGHT
		elif(direction == "left"):
			dir = Vector2.LEFT
		elif(direction == "up"):
			dir = Vector2.UP
		elif(direction == "down"):
			dir = Vector2.DOWN
		#knockback = dir * 150
		
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
	speed = 0
	
	var floor_save = File.new()
	floor_save.open("user://floor.save", File.WRITE)
	floor_save.store_line("1")
	floor_save.close()
	
	get_parent().get_node("CameraHolder/Camera2D/GameOver").game_over()
	get_tree().paused = true

func set_last_tile():
	var tiles
	if(current_room == 60):
		tiles = get_parent().get_child(3).get_child(0)
	elif(current_room == 61):
		tiles = get_parent().get_node("EndRoom").get_child(0)
	elif(current_room == 62):
		tiles = get_parent().get_node("BossRoom").get_child(0)
	else:
		tiles = get_parent().get_child(current_room + 6).get_child(0)
	var y_shift = (current_room / get_parent().columns) * 288
	var x_shift = (current_room % get_parent().columns) * 261
	
	var locked_x
	var locked_y
	for x in range(0, 9):
		if(respawn_x[x] + x_shift > position.x):
			if(x == 0 || position.x - (respawn_x[x-1] + x_shift) > respawn_x[x] + x_shift - position.x):
				locked_x = x
			else:
				locked_x = x - 1
			break
	if(locked_x == null):
		locked_x = 8
	for y in range(0, 9):
		if(respawn_y[y] + y_shift > position.y):
			if(y == 0 || position.y - (respawn_y[y-1] + y_shift) > respawn_y[y] + y_shift - position.y):
				locked_y = y
			else:
				locked_y = y - 1
			break
	if(locked_y == null):
		locked_y = 8
	
	if(tiles.get_cell(locked_x + 9, locked_y + 9) != -1):
		last_tile = Vector2(respawn_x[locked_x] + x_shift, respawn_y[locked_y] + y_shift + 9)

#for timer of level running out causing death
func _on_LevelCountdown_timeout():
	die()

#hurtbox enetered = damage taken
func _on_Hurtbox_area_shape_entered(area_id, area, _area_shape, _self_shape):
	if (area.get_name() == "Hitbox" && area.get_parent().get_parent().animator.visible == true):
		take_damage(area.get_parent().get_parent().damage, area.get_parent().get_parent().direction, false)
	elif(area.get_name() == "ProjectileHitbox"):
		take_damage(area.get_parent().damage, area.get_parent().direction, false)

#Player returns back to normal opacity once invincibility cooldown ends
func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1

#When a player hits a collision box
func _on_FeetBox_body_entered(body):
	if(respawn_cooldown.time_left == 0):
		$Fall.play()
		visible = false
		if(current_room != 62):
			get_parent().get_child(current_room + 3).player_active = false
		else:
			get_parent().get_child(4).player_active = false
		respawn_cooldown.start(1.1)

func _on_RespawnCooldown_timeout():
	visible = true
	if(current_room != 62):
		get_parent().get_child(current_room + 3).player_active = true
	else:
		get_parent().get_child(4).player_active = true
	position = last_tile
	take_damage(0.5,  "none", true)

func _on_RoomDetector_area_entered(area):
	current_room = area.get_parent().room_id
	
	transitioning = false
	animator.animation = "idle_" + direction
	get_parent().get_node("CameraHolder").move_and_slide(Vector2(0, 0))

func _on_BossMusic_finished():
	if(!$BossMusicLoop.playing):
		$BossMusicLoop.play()

func _on_RoomDetectionBox_body_entered(body):
	if(body.is_in_group("BossDetector")):
		$DungeonMusic.stop()
		$BossDoorOpen.play()
		get_parent().get_node("CameraHolder").get_child(0).shake(3.7, 20, 1)
		get_parent().get_node("StartRoom").get_node("BossDoor").animation = "opening"
		transitioning = true
		transitioned = true
		animator.animation = "idle_" + direction
		last_velocity = velocity
		velocity = Vector2.ZERO
		move_and_slide(velocity)
	
	if(!transitioning):
		transitioning = true
		transitioned = true
		transition()

func transition():
		animator.animation = "walk_" + direction
		
		if(velocity == Vector2.ZERO):
			velocity = last_velocity
			move_and_slide(velocity)
		if(current_room == 60 || (abs(position.x - ((current_room % get_parent().columns) * 261 + 391.5)) > abs(position.y - ((current_room / get_parent().columns) * 288 + 144)))):
			if(velocity.x > 0):
				direction = "right"
				velocity = Vector2(speed, 0)
			else:
				direction = "left"
				velocity = Vector2(-speed, 0)
		else:
			if(velocity.y > 0):
				direction = "down"
				velocity = Vector2(0, speed)
			else:
				direction = "up"
				velocity = Vector2(0, -speed)
		animator.animation = "walk_" + direction
		move_and_slide(velocity)
		
		if(direction == "right" || direction == "left"):
			$Transitioning.start(0.5)
			$Transitioned.start(1)
		elif(direction == "down"):
			$Transitioning.start(0.7)
			$Transitioned.start(1.2)
		else:
			$Transitioning.start(0.65)
			$Transitioned.start(1.15)

#func _on_Transitioning_timeout():
	#transitioning = false
	#animator.animation = "idle_" + direction
	#get_parent().get_node("CameraHolder").move_and_slide(Vector2(0, 0))

func _on_Transitioned_timeout():
	if(current_room == 62 && !$BossMusic.playing && !$BossMusicLoop.playing):
		$BossDoorClose.play()
		get_parent().get_node("BossRoom").get_node("BossDoorBody").get_node("BossDoor").animation = "closing"
		get_parent().get_node("BossRoom").get_node("BossDoorBody").get_node("CollisionShape2D").disabled = false
	else:
		transitioned = false

func _on_BossDoorClose_finished():
	transitioned = false
	$BossMusic.play()
