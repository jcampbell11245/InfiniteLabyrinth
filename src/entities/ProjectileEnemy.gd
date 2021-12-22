extends KinematicBody2D

export var speed : float
export var attack_speed : float
export var knockback_speed : float
export var damage : float
export var health : float
export var shoot_length : int
export var attack_cooldown_length : float

var direction
var knockback = Vector2.ZERO
var critical_chance = 0
var looting = 0

onready var player = get_parent().get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var move_cooldown = $MoveCooldown
onready var hurtbox = $Hurtbox/CollisionShape2D
onready var invincibility_cooldown = $InvincibilityCooldown
onready var coins = get_parent().get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Coins")
onready var overworld = get_parent().get_parent()

const Fireball = preload("res://src/entities/Fireball.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	var crit_file = File.new()
	if not crit_file.file_exists("user://damage.save"):
		print("Aborting, no savefile")
		return
	crit_file.open("user://damage.save", File.READ)
	critical_chance = int(crit_file.get_line())
	crit_file.close()
	
	var looting_file = File.new()
	if not looting_file.file_exists("user://looting.save"):
		print("Aborting, no savefile")
		return
	looting_file.open("user://looting.save", File.READ)
	looting = int(looting_file.get_line())
	looting_file.close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(player.transitioned == false):
		animate()
	elif(direction != null):
		animator.animation = "idle_" + direction

func _physics_process(delta):
	if(player.transitioned == false):
		if(get_parent().player_active == true && player.current_room == get_parent().room_id):
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
				if(direction == "left" && position.x < 424 || direction == "right" && position.x > 232 || direction == "up" && position.y > 214 || direction == "down" && position.y < 406):
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
	if(player.current_room == get_parent().room_id):
		#Reset to idle
		if animator.animation.substr(0, 5) == "shoot" && animator.frame == shoot_length:
			animator.animation = "idle_" + direction
		
		if(direction != null):
			if((abs(player.global_position.x - global_position.x) < 25 || abs(player.global_position.y - global_position.y) < 25) && animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
				animator.animation = "walk_" + direction
			elif(animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
				animator.animation = "shoot_" + direction
			elif(animator.animation.substr(0, 5) != "shoot"):
				animator.animation = "idle_" + direction

#Called when the enemy attacks
func attack():
	if(animator.visible == true && player.current_room == get_parent().room_id):
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
		
		var rng = RandomNumberGenerator.new()
		var rand = rng.randi_range(0, 30)
		
		if(rand - critical_chance < 0):
			health = 0
		else:
			health = health - 1
		if(health <= 0):
			die()

#Called when the enemy dies
func die():
	coins.add_coins(5 * overworld.floor_number * (looting + 1))
	get_parent().enemy_count -= 1
	get_parent().death_sound(get_name())
	get_parent().remove_child(self)

#Spawns a fireball at the enemy
func shoot_fireball():
	if(player.current_room == get_parent().room_id):
		$Attack.play()
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
		$SecondShotCountdown.start(0.5)
		$ThirdShotCountdown.start(1)

func _on_SecondShotCountdown_timeout():
	shoot_fireball()


func _on_ThirdShotCountdown_timeout():
	shoot_fireball()
