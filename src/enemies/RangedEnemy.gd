extends Enemy

# Wizard: backs away while the player is lined up with it on either axis, otherwise casts
# a burst of three fireballs in the direction it faces.

const Fireball := preload("res://src/projectiles/Fireball.tscn")
const BURST_COOLDOWN := 2.5 # Replaces attack_cooldown_length once a fireball is out
const BURST_SHOT_DELAY := 1.0

# Room-local bounds on backing away. The wizard faces the player and backs away from them,
# so facing left it backs towards RETREAT_LIMIT_RIGHT, and so on.
const RETREAT_LIMIT_LEFT := 232
const RETREAT_LIMIT_RIGHT := 424
const RETREAT_LIMIT_UP := 214
const RETREAT_LIMIT_DOWN := 406

var retreat_blocked := false # Backing away ran into something; shoot instead until the next burst

func _process(_delta: float) -> void:
	if !player.in_transition:
		animate()
	elif direction != "":
		_play("idle")

func _physics_process(delta: float) -> void:
	if player.in_transition || !room.player_active || !is_player_in_room():
		return
	
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically(0)
	
	if _is_retreating():
		var motion := -_to_player().normalized() * speed * delta
		var collision := move_and_collide(motion)
		# Grazing something still counts as moving; only a near-stop means it's stuck.
		retreat_blocked = collision != null && collision.get_travel().length() < motion.length() / 2
	elif attack_cooldown.time_left == 0:
		animate()
		attack()
	
	_apply_knockback(delta)

func animate() -> void:
	if !is_player_in_room():
		return
	if _animation_is("shoot") && animator.frame == attack_end_frame:
		_play("idle")
	
	if direction == "":
		return
	if _is_retreating():
		_play("walk")
	elif !_animation_is("shoot") && attack_cooldown.time_left == 0:
		_play("shoot")
	elif !_animation_is("shoot"):
		_play("idle")

func attack() -> void:
	retreat_blocked = false
	if animator.visible && is_player_in_room():
		attack_cooldown.start(attack_cooldown_length)

func shoot_fireball() -> void:
	if !is_player_in_room():
		return
	$Attack.play()
	var fireball: Projectile = Fireball.instantiate()
	room.add_child(fireball)
	fireball.position = room.clamp_to_floor(position, Projectile.SPAWN_MARGIN)
	fireball.direction = String(animator.animation).get_slice("_", 1)
	fireball.damage = damage
	attack_cooldown.start(BURST_COOLDOWN)

# Within CLOSE_RANGE of the player on at least one axis.
func _is_player_lined_up() -> bool:
	var offset := _to_player()
	return abs(offset.x) < CLOSE_RANGE || abs(offset.y) < CLOSE_RANGE

# Backs away while the player is lined up, until it reaches a wall or bumps into something.
# Pinned, it stands and shoots instead, then tries backing away again after the burst.
func _is_retreating() -> bool:
	return _is_player_lined_up() && _can_retreat() && !retreat_blocked && !_animation_is("shoot") && attack_cooldown.time_left == 0

func _can_retreat() -> bool:
	match direction:
		Direction.LEFT: return position.x < RETREAT_LIMIT_RIGHT
		Direction.RIGHT: return position.x > RETREAT_LIMIT_LEFT
		Direction.UP: return position.y < RETREAT_LIMIT_DOWN
		Direction.DOWN: return position.y > RETREAT_LIMIT_UP
	return false

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("shoot") && animator.frame == attack_frame:
		shoot_fireball()
		$SecondShotCountdown.start(BURST_SHOT_DELAY)
		$ThirdShotCountdown.start(BURST_SHOT_DELAY)

func _on_second_shot_countdown_timeout() -> void:
	shoot_fireball()

func _on_third_shot_countdown_timeout() -> void:
	shoot_fireball()
