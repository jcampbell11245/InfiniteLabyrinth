extends CharacterBody2D

# Emitted when the player steps on the start room's boss-door trigger. The player stops
# and waits; Overworld opens the door and the start room calls start_transition().
signal boss_door_reached
# Emitted when the pause after a room transition runs out. Overworld answers with
# end_transition(), after the boss-door cutscene if this was the boss room.
signal transition_pause_finished

# What the player is doing, read from the current animation. Animations are named
# "<action>_<direction>", e.g. "walkshoot_left".
enum Action { IDLE, WALK, ROLL, SLASH, SHOOT, WALKSHOOT, DAMAGE }
const ACTION_NAMES = ["idle", "walk", "roll", "slash", "shoot", "walkshoot", "damage"]
# Frame on which a one-shot action hands back to idle.
const ACTION_END_FRAME = {Action.SLASH: 7, Action.SHOOT: 1, Action.DAMAGE: 4}

# Respawn points are the centres of a room's 9x9 floor tiles, which start at cell (9, 9).
const FLOOR_ORIGIN = Vector2(304, 46) # Centre of room 0's top-left floor tile
const FLOOR_TILES = 9
const FLOOR_FIRST_CELL = Vector2i(9, 9)
const TILE_SIZE = 24

# How long enemies stay frozen after the player starts walking through a door, by direction.
const TRANSITION_PAUSE = {Direction.RIGHT: 1.0, Direction.LEFT: 1.0, Direction.DOWN: 1.2, Direction.UP: 1.15}

const Arrow = preload("res://src/projectiles/Arrow.tscn")

# Everything the player pressed this frame. Movement actions share their names with
# the Direction constants.
class FrameInput:
	var move = Vector2.ZERO # Sum of the held directions, not normalised
	var held = "" # First held direction, checked right, left, down, up
	var released = "" # First released direction, same order
	var roll = false # Rolls trigger on release
	var melee = false
	var ranged = false
	var quit = false

@onready var animator = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox/CollisionShape2D
@onready var hitbox = $HitboxPivot/Hitbox/CollisionShape2D
@onready var shoot_cooldown = $ShootCooldown
@onready var invincibility_cooldown = $InvincibilityCooldown
@onready var level_countdown = $LevelCountdown # Time left to clear the floor
@onready var respawn_cooldown = $RespawnCooldown # Time spent falling down a pitfall
@onready var rolling = $Rolling
@onready var roll_cooldown = $RollCooldown

var speed = 125 # Pixels/sec
var current_room = 0
var direction = Direction.RIGHT # Direction the player is facing

var knockback = Vector2.ZERO
var last_tile = Vector2.ZERO # Where the player respawns after falling down a pitfall
var last_velocity = Vector2.ZERO # Walking velocity when the boss-door cutscene started

# Room transitions have two overlapping phases. While auto_walking the player ignores
# input and walks through the doorway until it enters the next room. in_transition lasts
# until the TransitionPause timer (and any boss-door cutscene) ends; enemies freeze meanwhile.
var auto_walking = false
var in_transition = false

func _ready():
	z_index = 2

func _process(_delta):
	Game.timer_text.set_text(str(floor(level_countdown.get_time_left())))

func _physics_process(delta):
	if(!auto_walking):
		var input = _read_input()
		_handle_input(input)
		_update_animation(input)
		_update_hitboxes()
	if(visible):
		move_and_slide()

	# Knockback is moved separately so it doesn't overwrite the movement velocity
	var move_velocity = velocity
	knockback = knockback.move_toward(Vector2.ZERO, 300 * delta)
	velocity = knockback
	move_and_slide()
	knockback = velocity
	velocity = move_velocity

	_update_respawn_point()

func _read_input():
	var input = FrameInput.new()
	for dir in [Direction.RIGHT, Direction.LEFT, Direction.DOWN, Direction.UP]:
		if Input.is_action_pressed(dir):
			input.move += Direction.to_vector(dir)
			if input.held == "":
				input.held = dir
		if input.released == "" && Input.is_action_just_released(dir):
			input.released = dir
	input.roll = Input.is_action_just_released("roll")
	input.melee = Input.is_action_just_pressed("melee_attack")
	input.ranged = Input.is_action_just_pressed("ranged_attack")
	input.quit = Input.is_action_just_released("quit")
	return input

# Movement, rolling, attacks and arrows. Runs before _update_animation, so the checks
# here see the animation from the previous frame.
func _handle_input(input):
	if(rolling.time_left == 0):
		velocity = Vector2.ZERO

	if(input.roll && rolling.time_left == 0 && roll_cooldown.time_left == 0):
		velocity += Direction.to_vector(direction)
		speed *= 2
		rolling.start(0.25)
		set_collision_mask_value(Constants.Layer.GENERAL, false)
		hitbox.disabled = true
		hurtbox.disabled = true
	elif(rolling.time_left == 0):
		if(_action() not in [Action.SLASH, Action.SHOOT, Action.DAMAGE] && respawn_cooldown.time_left == 0):
			velocity += input.move
	velocity = velocity.normalized() * speed

	if(input.melee && _action() not in [Action.SLASH, Action.DAMAGE]):
		hitbox.disabled = false
		$Slash.play()

	if(input.ranged && _action() != Action.DAMAGE && shoot_cooldown.time_left == 0):
		var arrow = Arrow.instantiate()
		get_parent().add_child(arrow)
		arrow.position = position
		arrow.direction = direction
		shoot_cooldown.start(0.5)
		$Shoot.play()

	if(input.quit):
		get_tree().quit()

# Each check reads the action again, since earlier lines may have changed the animation.
func _update_animation(input):
	if(input.released != ""):
		direction = input.released
		_play(Action.IDLE)
	var action = _action()
	if(action in ACTION_END_FRAME && animator.frame == ACTION_END_FRAME[action]):
		_play(Action.IDLE)

	if(input.roll && roll_cooldown.time_left == 0):
		_play(Action.ROLL)
	elif(rolling.time_left == 0):
		if(_action() not in [Action.SLASH, Action.SHOOT, Action.DAMAGE, Action.WALKSHOOT] && input.held != ""):
			direction = input.held
			_play(Action.WALK)

	if(input.melee && _action() not in [Action.SLASH, Action.DAMAGE]):
		_play(Action.SLASH)

	if(input.ranged && _action() != Action.DAMAGE):
		if(_action() in [Action.WALK, Action.WALKSHOOT]):
			_play(Action.WALKSHOOT)
		else:
			_play(Action.SHOOT)

func _update_hitboxes():
	hurtbox.shape.set_size(Vector2(23, 48))
	if(direction == Direction.RIGHT):
		hurtbox.position = Vector2(-4.5, 0)
	elif(direction == Direction.LEFT):
		hurtbox.position = Vector2(4.5, 0)
	else:
		hurtbox.position = Vector2(0, 0)
	$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)

	if(_action() != Action.SLASH):
		hitbox.disabled = true

func _action():
	var index = ACTION_NAMES.find(String(animator.animation).get_slice("_", 0))
	return index if index != -1 else Action.IDLE

# Plays an action's animation facing `dir` (the player's direction by default).
func _play(action, dir = ""):
	animator.play(ACTION_NAMES[action] + "_" + (dir if dir != "" else direction))

# from_direction is the direction the hit travels in, which picks the flinch animation.
func take_damage(damage, from_direction, mute):
	if(invincibility_cooldown.time_left == 0):
		invincibility_cooldown.start(1)
		animator.modulate.a = 0.5

		_play(Action.DAMAGE, from_direction)

		if(!mute):
			$Hit.play()

		Game.hearts.update_health(-damage)
		if(Game.hearts.hearts <= 0):
			die()

func die():
	speed = 0

	SaveData.floor_number = 1
	SaveData.save()

	Game.game_over.game_over()
	get_tree().paused = true

# Remembers the floor tile nearest the player, if there is one, as the pitfall respawn point.
func _update_respawn_point():
	var tiles = Game.room_by_id(current_room).get_node("Tiles")
	# BUG(see BUGS.md): grid formula, also used for the special rooms (ids 60-62).
	var room_offset = Vector2((current_room % Constants.COLUMNS) * Constants.LEGACY_ROOM_WIDTH, (current_room / Constants.COLUMNS) * Constants.ROOM_SIZE.y)
	var first_tile = FLOOR_ORIGIN + room_offset
	var cell = Vector2i(_nearest_floor_index(first_tile.x, position.x), _nearest_floor_index(first_tile.y, position.y))

	if(tiles.get_cell_source_id(0, FLOOR_FIRST_CELL + cell) != -1):
		last_tile = first_tile + Vector2(cell) * TILE_SIZE + Vector2(0, 9)

# Index (0..FLOOR_TILES-1) of the floor tile centre nearest `value` along one axis.
func _nearest_floor_index(first_centre, value):
	for i in FLOOR_TILES:
		var centre = first_centre + i * TILE_SIZE
		if(centre > value):
			if(i == 0 || value - (centre - TILE_SIZE) > centre - value):
				return i
			return i - 1
	return FLOOR_TILES - 1

# The room whose enemies pause while the player is down a pitfall.
# BUG(see BUGS.md): meant to be the current room, but keeps the old lookup by Overworld
# child index (current_room + 3), which lands three rooms early.
func _pitfall_room():
	if(current_room == Constants.BOSS_ROOM):
		return Game.room_by_id(Constants.BOSS_ROOM)
	return get_parent().get_child(current_room + 3)

func _on_level_countdown_timeout():
	die()

func _on_hurtbox_area_shape_entered(_area_id, area, _area_shape, _self_shape):
	if (area.get_name() == "Hitbox" && area.get_parent().get_parent().animator.visible == true):
		take_damage(area.get_parent().get_parent().damage, area.get_parent().get_parent().direction, false)
	elif(area.get_name() == "ProjectileHitbox"):
		take_damage(area.get_parent().damage, area.get_parent().direction, false)

func _on_invincibility_cooldown_timeout():
	animator.modulate.a = 1

# Fell down a pitfall
func _on_feet_box_body_entered(_body):
	if(respawn_cooldown.time_left == 0):
		$Fall.play()
		visible = false
		_pitfall_room().player_active = false
		respawn_cooldown.start(1.1)

func _on_respawn_cooldown_timeout():
	visible = true
	_pitfall_room().player_active = true
	position = last_tile
	take_damage(0.5, "none", true)

func _on_rolling_timeout():
	create_tween().tween_property(self, "speed", speed / 2, 0.25) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_play(Action.IDLE)
	set_collision_mask_value(Constants.Layer.GENERAL, true)
	hitbox.disabled = false
	hurtbox.disabled = false
	roll_cooldown.start(1)

# --- Room transitions ---

# Touched a doorway's transition detector
func _on_room_detection_box_body_entered(body):
	if(body.is_in_group("BossDetector")):
		auto_walking = true
		in_transition = true
		_play(Action.IDLE)
		last_velocity = velocity
		velocity = Vector2.ZERO
		move_and_slide()
		boss_door_reached.emit()
	elif(!auto_walking):
		auto_walking = true
		in_transition = true
		start_transition()

# Walks the player out through the nearest door, along the axis it's furthest from the room centre.
func start_transition():
	if(velocity == Vector2.ZERO):
		velocity = last_velocity
		move_and_slide()
	var room_center = Vector2((current_room % Constants.COLUMNS) * Constants.LEGACY_ROOM_WIDTH + 391.5, (current_room / Constants.COLUMNS) * Constants.ROOM_SIZE.y + 144)
	if(current_room == Constants.START_ROOM || abs(position.x - room_center.x) > abs(position.y - room_center.y)):
		direction = Direction.RIGHT if velocity.x > 0 else Direction.LEFT
	else:
		direction = Direction.DOWN if velocity.y > 0 else Direction.UP
	velocity = Direction.to_vector(direction) * speed
	_play(Action.WALK)
	move_and_slide()

	$TransitionPause.start(TRANSITION_PAUSE[direction])

func end_transition():
	in_transition = false

# Entered the next room
func _on_room_detector_area_entered(area):
	current_room = area.get_parent().room_id
	auto_walking = false
	_play(Action.IDLE)

func _on_transition_pause_timeout():
	transition_pause_finished.emit()
