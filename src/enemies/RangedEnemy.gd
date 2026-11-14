extends Enemy

# Wizard: backs away while the player is lined up with it on either axis, otherwise casts
# a burst of three fireballs in the direction it faces.

const Fireball = preload("res://src/projectiles/Fireball.tscn")
const BURST_COOLDOWN = 2.5 # Replaces attack_cooldown_length once a fireball is out
const BURST_SHOT_DELAY = 1.0

# Room-local bounds on backing away, by facing direction.
# BUG(see BUGS.md): the vertical pair looks swapped, so they never stop the wizard at the
# wall it is backing towards.
const RETREAT_LIMIT_LEFT = 232
const RETREAT_LIMIT_RIGHT = 424
const RETREAT_LIMIT_UP = 214
const RETREAT_LIMIT_DOWN = 406

func _process(_delta):
	if(!player.in_transition):
		animate()
	elif(direction != null):
		_play("idle")

func _physics_process(delta):
	if(player.in_transition || !room.player_active || !is_player_in_room()):
		return

	if(_is_player_mostly_horizontal()):
		_face_player_horizontally()
	else:
		_face_player_vertically(0)

	if(_is_player_lined_up() && !_animation_is("shoot") && attack_cooldown.time_left == 0):
		if(_can_retreat()):
			move_and_collide(-_to_player().normalized() * speed * delta)
	elif(attack_cooldown.time_left == 0):
		animate()
		attack()

	_apply_knockback(delta)

func animate():
	if(!is_player_in_room()):
		return
	if(_animation_is("shoot") && animator.frame == attack_end_frame):
		_play("idle")

	if(direction == null):
		return
	if(_is_player_lined_up() && !_animation_is("shoot") && attack_cooldown.time_left == 0):
		_play("walk")
	elif(!_animation_is("shoot") && attack_cooldown.time_left == 0):
		_play("shoot")
	elif(!_animation_is("shoot")):
		_play("idle")

func attack():
	if(animator.visible && is_player_in_room()):
		attack_cooldown.start(attack_cooldown_length)

func shoot_fireball():
	if(!is_player_in_room()):
		return
	$Attack.play()
	var fireball = Fireball.instantiate()
	room.add_child(fireball)
	fireball.position = position
	fireball.direction = String(animator.animation).get_slice("_", 1)
	fireball.damage = damage
	attack_cooldown.start(BURST_COOLDOWN)

# Within CLOSE_RANGE of the player on at least one axis.
func _is_player_lined_up():
	var offset = _to_player()
	return abs(offset.x) < CLOSE_RANGE || abs(offset.y) < CLOSE_RANGE

func _can_retreat():
	match direction:
		Direction.LEFT: return position.x < RETREAT_LIMIT_RIGHT
		Direction.RIGHT: return position.x > RETREAT_LIMIT_LEFT
		Direction.UP: return position.y > RETREAT_LIMIT_UP
		Direction.DOWN: return position.y < RETREAT_LIMIT_DOWN
	return false

# BUG(see BUGS.md): the generator is never randomized, so every roll returns the same
# number.
func _roll_critical():
	return RandomNumberGenerator.new().randi_range(0, CRIT_ROLL_MAX) < critical_chance

func _looting_bonus():
	return (SaveData.looting_level + 1) / 10

func _on_animated_sprite_2d_frame_changed():
	if(_animation_is("shoot") && animator.frame == attack_frame):
		shoot_fireball()
		$SecondShotCountdown.start(BURST_SHOT_DELAY)
		$ThirdShotCountdown.start(BURST_SHOT_DELAY)

func _on_second_shot_countdown_timeout():
	shoot_fireball()

func _on_third_shot_countdown_timeout():
	shoot_fireball()
