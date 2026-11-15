class_name Player
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
const ACTION_NAMES: Array[String] = ["idle", "walk", "roll", "slash", "shoot", "walkshoot", "damage"]
# Frame on which a one-shot action hands back to idle.
const ACTION_END_FRAME := {Action.SLASH: 7, Action.SHOOT: 1, Action.DAMAGE: 4}

# Respawn points sit on a room's 9x9 floor, cells (9, 9) to (17, 17) of its Tiles map.
const FLOOR_FIRST_CELL := Vector2i(9, 9)
const FLOOR_LAST_CELL := Vector2i(17, 17)
const RESPAWN_PROBE := Vector2(0, 14) # Point below the player's origin that picks the tile
const RESPAWN_OFFSET := Vector2(0, -5) # Player's origin relative to the respawn tile's centre

# How long enemies stay frozen after the player starts walking through a door, by direction.
const KNOCKBACK_SPEED := 150.0 # Pixels/sec the player is pushed when hit; decays at 300/sec

const TRANSITION_PAUSE := {Direction.RIGHT: 1.0, Direction.LEFT: 1.0, Direction.DOWN: 1.2, Direction.UP: 1.15}

const HURTBOX_Y := -2.0 # Hurtbox centre; the sprite spans about -19.5..15
const HURTBOX_SIDE_OFFSET := 1.5 # Facing right the sprite sits this far left of centre

const Arrow := preload("res://src/projectiles/Arrow.tscn")

# Everything the player pressed this frame. Movement actions share their names with
# the Direction constants.
class FrameInput:
	var move := Vector2.ZERO # Sum of the held directions, not normalised
	var held := "" # First held direction, checked right, left, down, up
	var released := "" # First released direction, same order
	var roll := false # Rolls trigger on release
	var melee := false
	var ranged := false

var speed := 125 # Pixels/sec
var health: float = Constants.BASE_HEALTH # In hearts; halves happen
var current_room := Constants.START_ROOM
var direction := Direction.RIGHT # Direction the player is facing

var knockback := Vector2.ZERO
var last_tile := Vector2.ZERO # Where the player respawns after falling down a pitfall
var last_velocity := Vector2.ZERO # Walking velocity when the boss-door cutscene started

# Room transitions have two overlapping phases. While auto_walking the player ignores
# input and walks through the doorway until it enters the next room. in_transition lasts
# until the TransitionPause timer (and any boss-door cutscene) ends; enemies freeze meanwhile.
var auto_walking := false
var in_transition := false

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var invincibility_cooldown: Timer = $InvincibilityCooldown
@onready var level_countdown: Timer = $LevelCountdown # Time left to clear the floor
@onready var respawn_cooldown: Timer = $RespawnCooldown # Time spent falling down a pitfall
@onready var rolling: Timer = $Rolling
@onready var roll_cooldown: Timer = $RollCooldown

func _ready() -> void:
	z_index = 2
	health = SaveData.health_level + Constants.BASE_HEALTH

func _physics_process(delta: float) -> void:
	if !auto_walking:
		var input := _read_input()
		_handle_input(input)
		_update_animation(input)
		_update_hitboxes()
	if visible:
		move_and_slide()

	# Knockback is moved separately so it doesn't overwrite the movement velocity
	var move_velocity := velocity
	knockback = knockback.move_toward(Vector2.ZERO, 300 * delta)
	velocity = knockback
	move_and_slide()
	knockback = velocity
	velocity = move_velocity

	_update_respawn_point()

func _read_input() -> FrameInput:
	var input := FrameInput.new()
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
	return input

# Movement, rolling, attacks and arrows. Runs before _update_animation, so the checks
# here see the animation from the previous frame.
func _handle_input(input: FrameInput) -> void:
	if rolling.time_left == 0:
		velocity = Vector2.ZERO

	if input.roll && rolling.time_left == 0 && roll_cooldown.time_left == 0:
		velocity += Direction.to_vector(direction)
		speed *= 2
		rolling.start(0.25)
		set_collision_mask_value(Constants.Layer.GENERAL, false)
		hitbox.disabled = true
		hurtbox.disabled = true
	elif rolling.time_left == 0:
		if _action() not in [Action.SLASH, Action.SHOOT, Action.DAMAGE] && respawn_cooldown.time_left == 0:
			velocity += input.move
	velocity = velocity.normalized() * speed

	if input.melee && _action() not in [Action.SLASH, Action.DAMAGE]:
		hitbox.disabled = false
		$Slash.play()

	if input.ranged && _action() != Action.DAMAGE && shoot_cooldown.time_left == 0:
		var arrow: Projectile = Arrow.instantiate()
		get_parent().add_child(arrow)
		arrow.position = position
		arrow.direction = direction
		shoot_cooldown.start(0.5)
		$Shoot.play()

# Each check reads the action again, since earlier lines may have changed the animation.
func _update_animation(input: FrameInput) -> void:
	if input.released != "":
		direction = input.released
		_play(Action.IDLE)
	var action := _action()
	if action in ACTION_END_FRAME && animator.frame == ACTION_END_FRAME[action]:
		_play(Action.IDLE)

	if input.roll && roll_cooldown.time_left == 0:
		_play(Action.ROLL)
	elif rolling.time_left == 0:
		if _action() not in [Action.SLASH, Action.SHOOT, Action.DAMAGE, Action.WALKSHOOT] && input.held != "":
			direction = input.held
			_play(Action.WALK)

	if input.melee && _action() not in [Action.SLASH, Action.DAMAGE]:
		_play(Action.SLASH)

	if input.ranged && _action() != Action.DAMAGE:
		if _action() in [Action.WALK, Action.WALKSHOOT]:
			_play(Action.WALKSHOOT)
		else:
			_play(Action.SHOOT)

# The hurtbox's size is set in the scene to cover the sprite; facing sideways the sprite
# sits a little off-centre, so the hurtbox follows it.
func _update_hitboxes() -> void:
	if direction == Direction.RIGHT:
		hurtbox.position = Vector2(-HURTBOX_SIDE_OFFSET, HURTBOX_Y)
	elif direction == Direction.LEFT:
		hurtbox.position = Vector2(HURTBOX_SIDE_OFFSET, HURTBOX_Y)
	else:
		hurtbox.position = Vector2(0, HURTBOX_Y)
	$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)

	if _action() != Action.SLASH:
		hitbox.disabled = true

func _action() -> Action:
	var index := ACTION_NAMES.find(String(animator.animation).get_slice("_", 0))
	if index == -1:
		return Action.IDLE
	return index as Action

# Plays an action's animation facing `dir` (the player's direction by default).
func _play(action: Action, dir := "") -> void:
	animator.play(ACTION_NAMES[action] + "_" + (dir if dir != "" else direction))

# from_direction is the direction the hit travels in, which picks the flinch animation and
# the knockback. Pass "" for damage with no flinch or knockback (falling down a pitfall).
func take_damage(damage: float, from_direction: String, mute: bool) -> void:
	if invincibility_cooldown.time_left == 0:
		invincibility_cooldown.start(1)
		animator.modulate.a = 0.5

		if from_direction != "":
			_play(Action.DAMAGE, from_direction)
			knockback = Direction.to_vector(from_direction) * KNOCKBACK_SPEED

		if !mute:
			$Hit.play()

		health -= damage
		Game.health_changed.emit(health)
		if health <= 0:
			die()

# GameOver takes it from here.
func die() -> void:
	speed = 0
	# Let the killing blow's sound finish now instead of resuming after the pause.
	$Hit.process_mode = Node.PROCESS_MODE_ALWAYS
	Game.player_died.emit()
	get_tree().paused = true

# Remembers the floor tile nearest the player, if there is one, as the pitfall respawn point.
func _update_respawn_point() -> void:
	var room := Game.room_by_id(current_room)
	var tiles: TileMap = room.get_node("Tiles")
	var local := position - room.position + RESPAWN_PROBE
	var cell := tiles.local_to_map(local).clamp(FLOOR_FIRST_CELL, FLOOR_LAST_CELL)
	if tiles.get_cell_source_id(0, cell) != -1:
		last_tile = room.position + tiles.map_to_local(cell) + RESPAWN_OFFSET

func _on_level_countdown_timeout() -> void:
	die()

func _on_hurtbox_area_shape_entered(_area_id: RID, area: Area2D, _area_shape: int, _self_shape: int) -> void:
	if respawn_cooldown.time_left > 0: # Down a pitfall
		return
	if (area.get_name() == "Hitbox" && area.get_parent().get_parent().animator.visible == true):
		take_damage(area.get_parent().get_parent().damage, area.get_parent().get_parent().direction, false)
	elif area.get_name() == "ProjectileHitbox":
		take_damage(area.get_parent().damage, area.get_parent().direction, false)

func _on_invincibility_cooldown_timeout() -> void:
	animator.modulate.a = 1

# Fell down a pitfall
func _on_feet_box_body_entered(_body: Node2D) -> void:
	if respawn_cooldown.time_left == 0:
		$Fall.play()
		visible = false
		knockback = Vector2.ZERO
		Game.room_by_id(current_room).player_active = false
		respawn_cooldown.start(1.1)

func _on_respawn_cooldown_timeout() -> void:
	visible = true
	Game.room_by_id(current_room).player_active = true
	position = last_tile
	take_damage(0.5, "", true)

func _on_rolling_timeout() -> void:
	@warning_ignore("integer_division")
	create_tween().tween_property(self, "speed", speed / 2, 0.25) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_play(Action.IDLE)
	set_collision_mask_value(Constants.Layer.GENERAL, true)
	hitbox.disabled = false
	hurtbox.disabled = false
	roll_cooldown.start(1)

# --- Room transitions ---

# Touched a doorway's transition detector
func _on_room_detection_box_body_entered(body: Node2D) -> void:
	if body.is_in_group("BossDetector"):
		auto_walking = true
		in_transition = true
		_play(Action.IDLE)
		last_velocity = velocity
		velocity = Vector2.ZERO
		move_and_slide()
		boss_door_reached.emit()
	elif !auto_walking:
		auto_walking = true
		in_transition = true
		start_transition()

# Walks the player out through the nearest door, along the axis it's furthest from the room centre.
func start_transition() -> void:
	if velocity == Vector2.ZERO:
		velocity = last_velocity
		move_and_slide()
	var room_center := Game.room_by_id(current_room).position + Room.CENTRE
	if current_room == Constants.START_ROOM || abs(position.x - room_center.x) > abs(position.y - room_center.y):
		direction = Direction.RIGHT if velocity.x > 0 else Direction.LEFT
	else:
		direction = Direction.DOWN if velocity.y > 0 else Direction.UP
	velocity = Direction.to_vector(direction) * speed
	_play(Action.WALK)
	move_and_slide()

	$TransitionPause.start(TRANSITION_PAUSE[direction])

func end_transition() -> void:
	in_transition = false

# Entered the next room
func _on_room_detector_area_entered(area: Area2D) -> void:
	current_room = area.get_parent().room_id
	auto_walking = false
	_play(Action.IDLE)
	Game.room_entered.emit(current_room)

func _on_transition_pause_timeout() -> void:
	transition_pause_finished.emit()
