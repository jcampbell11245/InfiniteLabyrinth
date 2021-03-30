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

onready var player = get_parent().get_parent().get_node("Player2D")
onready var animator = $AnimatedSprite
onready var attack_cooldown = $AttackCooldown
onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
onready var hurtbox = $Hurtbox/CollisionShape2D
onready var invincibility_cooldown = $InvincibilityCooldown
onready var coins = get_parent().get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Coins")
onready var overworld = get_parent().get_parent()

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
	if(abs(player.global_position.x - global_position.x) > abs(player.global_position.y - global_position.y) && player.current_room == 62):
		if(player.global_position.x - global_position.x < 0):
			direction = "left"
		else:
			direction = "right"
	elif (player.current_room == 62):
		if(player.global_position.y - global_position.y < 0):
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
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && player.current_room == 62):
		var dir = (player.global_position - global_position).normalized()
		move_and_collide(dir * speed * delta)
	elif(attack_cooldown.time_left == 0 && player.current_room == 62):
		animate()
		attack()
	print(animator.animation)
		
	#Knockback
	knockback = knockback.move_toward(Vector2.ZERO, 200 * delta)
	knockback = move_and_slide(knockback)
	
	animate()
	
	print(direction)

#Animates the enemy
func animate():
	#Reset to idle
	if animator.animation.substr(0, 5) == "slash" && animator.frame == slash_length:
		animator.animation = "idle_" + direction
	
	if((abs(player.global_position.x - global_position.x) > 25 || abs(player.global_position.y - global_position.y) > 25) && animator.animation.substr(0, 5) != "slash" && player.current_room == 62):
		animator.animation = "walk_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && attack_cooldown.time_left == 0 && player.current_room == 62):
		animator.animation = "slash_" + direction
	elif(animator.animation.substr(0, 5) != "slash" && player.current_room == 62):
		animator.animation = "idle_" + direction

#Called when the enemy attacks
func attack():
	if(animator.visible == true):
		attack_cooldown.start(attack_cooldown_length)

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
	get_parent().enemy_count -= 1
	get_parent().death_sound(get_name().substr(0, 6))
	get_parent().remove_child(self)

func _on_InvincibilityCooldown_timeout():
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_Hurtbox_area_shape_entered(area_id, area, area_shape, self_shape):
	if (area.get_name() == "Hitbox"):
		take_damage(area.get_parent().get_parent().direction)
	elif (area.get_name() == "ArrowHitbox"):
		take_damage(area.get_parent().direction)

func _on_AnimatedSprite_frame_changed():
	if(animator.animation.substr(0, 5) == "slash" && animator.frame == attack_speed):
		$Attack.play()
		hitbox.disabled = false


