extends CharacterBody2D

@export var speed : float
@export var attack_speed : float
@export var knockback_speed : float
@export var damage : float
@export var health : float
@export var shoot_length : int
@export var attack_cooldown_length : float

var direction
var knockback = Vector2.ZERO
var critical_chance = 0
var looting = 0

@onready var player = Game.player
@onready var animator = $AnimatedSprite2D
@onready var attack_cooldown = $AttackCooldown
@onready var move_cooldown = $MoveCooldown
@onready var hurtbox = $Hurtbox/CollisionShape2D
@onready var invincibility_cooldown = $InvincibilityCooldown

const Fireball = preload("res://src/projectiles/Fireball.tscn")

func _ready():
	critical_chance = SaveData.damage_level
	looting = SaveData.looting_level

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(player.in_transition == false):
		animate()
	elif(direction != null):
		animator.play("idle_" + direction)

func _physics_process(delta):
	if(player.in_transition == false):
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
			set_velocity(knockback)
			move_and_slide()
			knockback = velocity

#Animates the enemy
func animate():
	if(player.current_room == get_parent().room_id):
		#Reset to idle
		if animator.animation.substr(0, 5) == "shoot" && animator.frame == shoot_length:
			animator.play("idle_" + direction)
		
		if(direction != null):
			if((abs(player.global_position.x - global_position.x) < 25 || abs(player.global_position.y - global_position.y) < 25) && animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
				animator.play("walk_" + direction)
			elif(animator.animation.substr(0, 5) != "shoot" && attack_cooldown.time_left == 0):
				animator.play("shoot_" + direction)
			elif(animator.animation.substr(0, 5) != "shoot"):
				animator.play("idle_" + direction)

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
		
		knockback = Direction.to_vector(direction) * knockback_speed
		
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
	Game.coins.add_coins(20 * Game.overworld.floor_number * 1+((looting + 1)/10))
	get_parent().enemy_count -= 1
	get_parent().death_sound(get_name())
	get_parent().remove_child(self)

#Spawns a fireball at the enemy
func shoot_fireball():
	if(player.current_room == get_parent().room_id):
		$Attack.play()
		var fireball = Fireball.instantiate()
		get_parent().add_child(fireball)
		fireball.position = position
		fireball.direction = animator.animation.split("_")[1]
		fireball.damage = damage
		attack_cooldown.start(2.5)

func _on_invincibility_cooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_animated_sprite_2d_frame_changed():
	if(animator.animation.substr(0, 5) == "shoot" && animator.frame == attack_speed):
		shoot_fireball()
		$SecondShotCountdown.start(1)
		$ThirdShotCountdown.start(1)

func _on_second_shot_countdown_timeout():
	shoot_fireball()

func _on_third_shot_countdown_timeout():
	shoot_fireball()
