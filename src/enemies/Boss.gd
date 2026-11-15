extends Enemy

# Switches at random between two modes each time it is hit: chasing the player to slash
# them, or backing away and firing a laser every time its attack cooldown runs out.

enum Mode { CHASE, RANGED }

const Laser := preload("res://src/projectiles/Laser.tscn")
const LASER_COOLDOWN := 1.0

var mode := Mode.CHASE
var swing_rest := 0.0 # Seconds left standing idle after a slash before the next one

@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D

func _ready() -> void:
	super()
	direction = Direction.RIGHT

func _process(_delta: float) -> void:
	if !_animation_is("slash"):
		hitbox.disabled = true

func _physics_process(delta: float) -> void:
	if player.in_transition:
		return
	swing_rest = max(swing_rest - delta, 0.0)
	
	if is_player_in_room():
		if _is_player_mostly_horizontal():
			_face_player_horizontally()
		else:
			_face_player_vertically()
	
	if !_animation_is("slash"):
		$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)
	
	if _is_player_far() && !_animation_is("slash") && is_player_in_room():
		var dir := _to_player().normalized()
		if mode == Mode.RANGED:
			dir = -dir
		move_and_collide(dir * speed * delta)
	elif is_player_in_room():
		animate()
		attack()
	
	_apply_knockback(delta)
	animate()

# Walks towards (or away from) a far player. Up close it slashes, then stands idle for
# attack_cooldown_length before the next slash.
func animate() -> void:
	if _animation_is("slash") && animator.frame == attack_end_frame:
		_play("idle")
		swing_rest = attack_cooldown_length
	
	if _animation_is("slash") || !is_player_in_room():
		return
	if _is_player_far():
		_play("walk")
	elif swing_rest == 0:
		_play("slash")
	else:
		_play("idle")

func attack() -> void:
	if animator.visible:
		attack_cooldown.start(attack_cooldown_length)

func shoot_laser() -> void:
	if !is_player_in_room():
		return
	var laser: Projectile = Laser.instantiate()
	room.add_child(laser)
	laser.position = room.clamp_to_floor(position, Projectile.SPAWN_MARGIN)
	laser.direction = String(animator.animation).get_slice("_", 1)
	laser.damage = damage
	attack_cooldown.start(LASER_COOLDOWN)

func die() -> void:
	$Won.visible = true
	get_tree().paused = true

# A critical hit does double damage instead of killing outright.
func _lose_health(amount: float, critical: bool) -> void:
	health -= amount * 2 if critical else amount

func _after_hit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	mode = rng.randi_range(Mode.CHASE, Mode.RANGED) as Mode
	attack()

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("slash") && animator.frame == attack_frame && mode == Mode.CHASE:
		hitbox.disabled = false

func _on_attack_cooldown_timeout() -> void:
	if mode == Mode.RANGED:
		shoot_laser()
