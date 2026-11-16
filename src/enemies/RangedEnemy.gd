extends Enemy

# Wizard: backs away while the player is lined up with it on either axis, otherwise casts
# a burst of three fireballs, half a second apart, in the direction it faces. A fireball the
# player hits back is batted back again just before it lands, unless the wizard fumbles it
# (DEFLECT_MISS_CHANCE each time) or is stunned. The two can rally a fireball back and
# forth, stronger and faster each time.

const Fireball := preload("res://src/projectiles/Fireball.tscn")
# Burst cooldown (replaces attack_cooldown_length once a fireball is out), the delay
# between each of the three shots and the deflect miss chance are in Tuning.
const DEFLECT_REACH := 22.0 # Pixels ahead of the wizard where it bats a fireball back
const DEFLECT_WIDTH := 12.0 # Pixels either side of a fireball's path that still count

# Room-local bounds on backing away. The wizard faces the player and backs away from them,
# so facing left it backs towards RETREAT_LIMIT_RIGHT, and so on.
const RETREAT_LIMIT_LEFT := 232
const RETREAT_LIMIT_RIGHT := 424
const RETREAT_LIMIT_UP := 214
const RETREAT_LIMIT_DOWN := 406

var retreat_blocked := false # Backing away ran into something; shoot instead until the next burst
var _judged: Dictionary = {} # Fireball -> its deflections when last swung at, so each return gets one try

func _process(_delta: float) -> void:
	if !player.in_transition && !is_stunned():
		_update_windup()
		animate()
	elif direction != "":
		_play("idle")

func _physics_process(delta: float) -> void:
	if player.in_transition || !room.player_active || !is_player_in_room():
		return
	if is_stunned(): # Parried
		_apply_knockback(delta)
		return
	
	_try_deflect()
	if !_is_bursting():
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
	Juice.play($Attack)
	var fireball: Projectile = Fireball.instantiate()
	room.add_child(fireball)
	fireball.position = room.clamp_to_floor(position, Projectile.SPAWN_MARGIN)
	fireball.direction = direction
	fireball.damage = damage
	fireball.speed = Tuning.fireball_speed
	attack_cooldown.start(Tuning.wizard_burst_cooldown)

func _attack_action() -> String:
	return "shoot"

# Swings at any player-deflected fireball about to hit, once per return.
func _try_deflect() -> void:
	for node in room.get_children():
		var shot := node as Projectile
		if shot == null || !shot.deflectable || shot.hostile_to_player || shot._hit:
			continue
		if _judged.get(shot, -1) == shot.deflections || !_is_incoming(shot):
			continue
		_judged[shot] = shot.deflections
		if randf() < Tuning.wizard_deflect_miss_chance:
			continue # Fumbled; it flies on and hits
		_face(Direction.to_vector(shot.direction) * -1)
		shot.deflect(direction)
		Juice.flash(animator, 0.1, Color(0.8, 0.6, 1.0))
		Juice.play($Attack)
	# Forget fireballs that have gone.
	for shot in _judged.keys():
		if !is_instance_valid(shot):
			_judged.erase(shot)

# Heading straight at the wizard and about to arrive.
func _is_incoming(shot: Projectile) -> bool:
	var heading := Direction.to_vector(shot.direction)
	var to_me := global_position - shot.global_position
	var ahead := to_me.dot(heading)
	return ahead > 0 && ahead < DEFLECT_REACH && absf(to_me.cross(heading)) < DEFLECT_WIDTH

# Turns to face along `facing`, one of the four direction vectors.
func _face(facing: Vector2) -> void:
	for dir in [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]:
		if Direction.to_vector(dir).is_equal_approx(facing):
			direction = dir

# From the start of the shoot animation until the third shot is out. The wizard keeps
# the facing it started the burst with, so all three shots fly the same way.
func _is_bursting() -> bool:
	return _animation_is("shoot") || !$ThirdShotCountdown.is_stopped()

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
		$SecondShotCountdown.start(Tuning.wizard_shot_delay)
		$ThirdShotCountdown.start(Tuning.wizard_shot_delay * 2)

func _on_second_shot_countdown_timeout() -> void:
	shoot_fireball()

func _on_third_shot_countdown_timeout() -> void:
	shoot_fireball()
