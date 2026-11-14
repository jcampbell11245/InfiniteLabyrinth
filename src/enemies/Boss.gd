extends Enemy

# Switches at random between two modes each time it is hit: chasing the player to slash
# them, or backing away and firing a laser every time its attack cooldown runs out.

enum Mode { CHASE, RANGED }

const Laser = preload("res://src/projectiles/Laser.tscn")
const LASER_COOLDOWN = 1.0

var mode = Mode.CHASE

@onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D

func _ready():
	super()
	direction = Direction.RIGHT

func _process(_delta):
	if(!_animation_is("slash")):
		hitbox.disabled = true

func _physics_process(delta):
	if(player.in_transition):
		return

	if(is_player_in_room()):
		if(_is_player_mostly_horizontal()):
			_face_player_horizontally()
		else:
			_face_player_vertically()

	if(!_animation_is("slash")):
		$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)

	if(_is_player_far() && !_animation_is("slash") && is_player_in_room()):
		var dir = _to_player().normalized()
		if(mode == Mode.RANGED):
			dir = -dir
		move_and_collide(dir * speed * delta)
	elif(is_player_in_room()):
		animate()
		attack()

	_apply_knockback(delta)
	animate()

# BUG(see BUGS.md): never returns to idle while the player is in the room, because the
# slash branch catches every case the idle branch would.
func animate():
	if(_animation_is("slash") && animator.frame == attack_end_frame):
		_play("idle")

	if(_is_player_far() && !_animation_is("slash") && is_player_in_room()):
		_play("walk")
	elif(!_animation_is("slash") && is_player_in_room()):
		_play("slash")

func attack():
	if(animator.visible):
		attack_cooldown.start(attack_cooldown_length)

func shoot_laser():
	if(!is_player_in_room()):
		return
	var laser = Laser.instantiate()
	room.add_child(laser)
	laser.position = position
	laser.direction = String(animator.animation).get_slice("_", 1)
	laser.damage = damage
	attack_cooldown.start(LASER_COOLDOWN)

func die():
	$Won.visible = true
	get_tree().paused = true

func _lose_health(critical):
	health -= 2 if critical else 1

func _after_hit():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	mode = rng.randi_range(Mode.CHASE, Mode.RANGED)
	attack()

func _on_animated_sprite_2d_frame_changed():
	if(_animation_is("slash") && animator.frame == attack_frame && mode == Mode.CHASE):
		hitbox.disabled = false

func _on_attack_cooldown_timeout():
	if(mode == Mode.RANGED):
		shoot_laser()
