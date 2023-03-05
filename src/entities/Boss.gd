extends KinematicBody2D

export var speed : float
export var attack_speed : float
export var knockback_speed : float
export var damage : float
export var health : float
export var slash_length : int
export var attack_cooldown_length : float

var direction = "right"
var knockback = Vector2.ZERO
var critical_chance = 0
var mode = 0

onready var player = get_parent().get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
onready var hurtbox = $Hurtbox/CollisionShape2D
onready var invincibility_cooldown = $InvincibilityCooldown
onready var coins = get_parent().get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Coins")
onready var overworld = get_parent().get_parent()
const Fireball = preload("res://src/entities/Laser.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	var crit_file = File.new()
	if not crit_file.file_exists("user://damage.save"):
		print("Aborting, no savefile")
		return
	crit_file.open("user://damage.save", File.READ)
	critical_chance = int(crit_file.get_line())
	crit_file.close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if animator.animation.substr(0, 5) != "slash":
		hitbox.disabled = true
	
func _physics_process(delta):
	if(!player.transitioned):
		if(abs(PlayerVariables.global_position.x - global_position.x) > abs(PlayerVariables.global_position.y - global_position.y) && PlayerVariables.current_room == 62):
			if(PlayerVariables.global_position.x - global_position.x < 0):
				direction = "left"
			else:
				direction = "right"
		elif (PlayerVariables.current_room == 62):
			if(PlayerVariables.global_position.y - global_position.y < 0):
				direction = "up"
				z_index = 10
			else:
				direction = "down"
				z_index = 1
		
		if(animator.animation.substr(0, 5) != "slash"):
			if(direction == "left"):
				$HitboxPivot.rotation_degrees = 180
			elif(direction == "right"):
				$HitboxPivot.rotation_degrees = 0
			elif(direction == "up"):
				$HitboxPivot.rotation_degrees = 270
			elif(direction == "down"):
				$HitboxPivot.rotation_degrees = 90
		
		if((abs(PlayerVariables.global_position.x - global_position.x) > 25 || abs(PlayerVariables.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && PlayerVariables.current_room == 62):
			var dir
			if(mode == 0):
				dir = (PlayerVariables.global_position - global_position).normalized()
			else:
				dir = -(PlayerVariables.global_position - global_position).normalized()
			move_and_collide(dir * speed * delta)
		elif(PlayerVariables.current_room == 62):
			animate()
			attack()
			
		#Knockback
		knockback = knockback.move_toward(Vector2.ZERO, 200 * delta)
		knockback = move_and_slide(knockback)
		
		animate()
	

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == slash_length:
		animator.animation = "idle_" + direction
	
	if((abs(PlayerVariables.global_position.x - global_position.x) > 25 || abs(PlayerVariables.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && PlayerVariables.current_room == 62):
		animator.animation = "walk_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && PlayerVariables.current_room == 62):
		animator.animation = "slash_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && PlayerVariables.current_room == 62):
		animator.animation = "idle_" + direction

#Called when the enemy attacks
func attack():
	if(animator.visible == true):
		attack_cooldown.start(attack_cooldown_length)
		
#Spawns a fireball at the enemy
func shoot_fireball():
	if(PlayerVariables.current_room == get_parent().room_id):
		var fireball = Fireball.instance()
		get_parent().add_child(fireball)
		fireball.position = position
		fireball.direction = animator.animation.split("_")[1]
		fireball.damage = damage
		attack_cooldown.start(1)

#Called when the enemy takes damage
func take_damage(direction):
	if(invincibility_cooldown.time_left == 0):
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
		
		if animator.animation.substr(0, 5) == "slash":
			animator.animation = "idle_" + direction
			
		hurtbox.disabled = true
		invincibility_cooldown.start(1)
		animator.modulate.a = 0.5
		
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var rand = rng.randi_range(0, 30)
		
		if(rand - critical_chance < 0):
			health = health - 2
		else:
			health = health - 1
		if(health <= 0):
			die()
		
		var rng2 = RandomNumberGenerator.new()
		rng2.randomize()
		mode = rng2.randi_range(0, 1)
		attack()

#Called when the enemy dies
func die():
	#print(get_parent().get_node("Won").visible)
	get_node("Won").visible = true
	#print(get_parent().get_node("Won").visible)
	get_tree().paused = true

func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_Hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_AnimatedSprite_frame_changed():
	if(animator.animation.substr(0, 5) == "slash" && animator.frame == 5):
		if(mode == 0):
			hitbox.disabled = false

func _on_AttackCooldown_timeout():
	if(mode == 1):
		shoot_fireball()
