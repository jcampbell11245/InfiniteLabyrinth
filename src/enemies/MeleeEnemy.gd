extends CharacterBody2D

@export var speed : float
@export var attack_speed : float
@export var knockback_speed : float
@export var damage : float
@export var health : float
@export var slash_length : int
@export var attack_cooldown_length : float
@export var only_hit_during_attack : bool
@export var starting_direction = "right"

var direction
var knockback = Vector2.ZERO
var critical_chance = 0
var looting = 0

@onready var player = Game.player
@onready var animator = $AnimatedSprite2D
@onready var attack_cooldown = $AttackCooldown
@onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
@onready var hurtbox = $Hurtbox/CollisionShape2D
@onready var invincibility_cooldown = $InvincibilityCooldown

func _ready():
	critical_chance = SaveData.damage_level
	looting = SaveData.looting_level
	
	direction = starting_direction
	animator.play("idle_" + direction)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(player.in_transition == false):
		if animator.animation.substr(0, 5) != "slash":
			hitbox.disabled = true
		
		animate()
	else:
		animator.play("idle_" + direction)

func _physics_process(delta):
	if(player.in_transition == false):
		if(abs(player.global_position.x - global_position.x) > abs(player.global_position.y - global_position.y) && (is_detected() || $InvincibilityCooldown.time_left != 0 || only_hit_during_attack && $Block.playing) && player.current_room == get_parent().room_id):
			if(player.global_position.x - global_position.x < 0):
				direction = "left"
			else:
				direction = "right"
		elif (is_detected() || $InvincibilityCooldown.time_left != 0 || only_hit_during_attack && $Block.playing && player.current_room == get_parent().room_id):
			if(player.global_position.y - global_position.y < 0):
				direction = "up"
				z_index = 10
			else:
				direction = "down"
				z_index = 1
		
		if(animator.animation.substr(0, 5) != "slash"):
			$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)
			$DetectionZonePivot.rotation_degrees = Direction.to_rotation_degrees(direction)
		
		if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && is_detected()):
			var dir = (player.global_position - global_position).normalized()
			move_and_collide(dir * speed * delta)
		elif(attack_cooldown.time_left == 0) && is_detected():
			if(!only_hit_during_attack || $BlockStun.time_left == 0):
				animate()
				attack()
			
		#Knockback
		knockback = knockback.move_toward(Vector2.ZERO, 200 * delta)
		set_velocity(knockback)
		move_and_slide()
		knockback = velocity

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == slash_length:
		animator.play("idle_" + direction)
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && is_detected()):
		animator.play("walk_" + direction)
	elif(animator.animation.substr(0, 5) != "slash" && attack_cooldown.time_left == 0) && is_detected():
		animator.play("slash_" + direction)
	elif(animator.animation.substr(0, 5) != "slash"):
		animator.play("idle_" + direction)

#Called when the enemy attacks
func attack():
	if(animator.visible == true):
		attack_cooldown.start(attack_cooldown_length)

#Called when the enemy takes damage
func take_damage(direction):
	if(invincibility_cooldown.time_left == 0):
		knockback = Direction.to_vector(direction) * knockback_speed
		
		if(only_hit_during_attack && animator.animation.substr(0, 5) != "slash"):
			$BlockStun.start(1)
			$Block.play()
		else:
			if animator.animation.substr(0, 5) == "slash":
				animator.play("idle_" + direction)
			
			hurtbox.disabled = true
			invincibility_cooldown.start(0.3)
			animator.modulate.a = 0.5
			
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var rand = rng.randi_range(0, 30)
			
			if(rand - critical_chance < 0):
				$Crit.play()
				health = 0
			else:
				health = health - 1
			if(health <= 0):
				die()

#Called when the enemy dies
func die():
	if(only_hit_during_attack):
		Game.coins.add_coins(30 * Game.overworld.floor_number * 1+((looting + 1 /10)))
	else:
		Game.coins.add_coins(10 * Game.overworld.floor_number * 1+((looting + 1 /10)))
	get_parent().enemy_count -= 1
	get_parent().death_sound(get_name().substr(0, 6))
	get_parent().remove_child(self)

#Checks if the player is within the detection zone
func is_detected():
	return get_parent().player_active == true && $DetectionZonePivot/DetectionZone.get_overlapping_bodies().has(player)

func _on_invincibility_cooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_animated_sprite_2d_frame_changed():
	if(animator.animation.substr(0, 5) == "slash" && animator.frame == attack_speed):
		$Attack.play()
		hitbox.disabled = false
