extends CharacterBody2D

@export var speed : float
@export var attack_speed : float
@export var knockback_speed : float
@export var damage : float
@export var health : float
@export var slash_length : int
@export var attack_cooldown_length : float

var direction = "right"
var knockback = Vector2.ZERO
var critical_chance = 0
var mode = 0

@onready var player = Game.player
@onready var animator = $AnimatedSprite2D
@onready var attack_cooldown = $AttackCooldown
@onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
@onready var hurtbox = $Hurtbox/CollisionShape2D
@onready var invincibility_cooldown = $InvincibilityCooldown
const Fireball = preload("res://src/projectiles/Laser.tscn")

func _ready():
	critical_chance = SaveData.damage_level

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if animator.animation.substr(0, 5) != "slash":
		hitbox.disabled = true
	
func _physics_process(delta):
	if(!player.transitioned):
		if(abs(player.global_position.x - global_position.x) > abs(player.global_position.y - global_position.y) && player.current_room == Constants.BOSS_ROOM):
			if(player.global_position.x - global_position.x < 0):
				direction = "left"
			else:
				direction = "right"
		elif (player.current_room == Constants.BOSS_ROOM):
			if(player.global_position.y - global_position.y < 0):
				direction = "up"
				z_index = 10
			else:
				direction = "down"
				z_index = 1
		
		if(animator.animation.substr(0, 5) != "slash"):
			$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)
		
		if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && player.current_room == Constants.BOSS_ROOM):
			var dir
			if(mode == 0):
				dir = (player.global_position - global_position).normalized()
			else:
				dir = -(player.global_position - global_position).normalized()
			move_and_collide(dir * speed * delta)
		elif(player.current_room == Constants.BOSS_ROOM):
			animate()
			attack()
			
		#Knockback
		knockback = knockback.move_toward(Vector2.ZERO, 200 * delta)
		set_velocity(knockback)
		move_and_slide()
		knockback = velocity
		
		animate()
	

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == slash_length:
		animator.play("idle_" + direction)
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && player.current_room == Constants.BOSS_ROOM):
		animator.play("walk_" + direction)
	elif(animator.animation.substr(0, 5) != "slash" && player.current_room == Constants.BOSS_ROOM):
		animator.play("slash_" + direction)
	elif(animator.animation.substr(0, 5) != "slash" && player.current_room == Constants.BOSS_ROOM):
		animator.play("idle_" + direction)

#Called when the enemy attacks
func attack():
	if(animator.visible == true):
		attack_cooldown.start(attack_cooldown_length)
		
#Spawns a fireball at the enemy
func shoot_fireball():
	if(player.current_room == get_parent().room_id):
		var fireball = Fireball.instantiate()
		get_parent().add_child(fireball)
		fireball.position = position
		fireball.direction = animator.animation.split("_")[1]
		fireball.damage = damage
		attack_cooldown.start(1)

#Called when the enemy takes damage
func take_damage(direction):
	if(invincibility_cooldown.time_left == 0):
		knockback = Direction.to_vector(direction) * knockback_speed
		
		if animator.animation.substr(0, 5) == "slash":
			animator.play("idle_" + direction)
			
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
	get_node("Won").visible = true
	get_tree().paused = true

func _on_invincibility_cooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_animated_sprite_2d_frame_changed():
	if(animator.animation.substr(0, 5) == "slash" && animator.frame == 5):
		if(mode == 0):
			hitbox.disabled = false

func _on_attack_cooldown_timeout():
	if(mode == 1):
		shoot_fireball()
