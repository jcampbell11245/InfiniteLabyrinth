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
const WALK_FIRST_STEP := 1 # Walk frame a walk starts on; frame 0 is the standing pose

# Respawn points sit on the room's floor (Room.floor_rect, in cells of its Tiles map).
const RESPAWN_PROBE := Vector2(0, 14) # Point below the player's origin that picks the tile
const RESPAWN_OFFSET := Vector2(0, -5) # Player's origin relative to the respawn tile's centre

# How long enemies stay frozen after the player starts walking through a door, by direction.

const DOOR_PULL := 10.0 # Per second: how hard the auto-walk centres the player in a doorway

const TRANSITION_PAUSE := {Direction.RIGHT: 1.0, Direction.LEFT: 1.0, Direction.DOWN: 1.2, Direction.UP: 1.15}

const PUSH_OUT_TRIES := 4 # Enemies a roll can be nudged out of, one after another
const PUSH_OUT_GAP := 0.5 # Pixels left between the player's feet and the enemy's after a nudge

const HURTBOX_Y := -2.0 # Hurtbox centre; the sprite spans about -19.5..15
const HURTBOX_SIDE_OFFSET := 1.5 # Facing right the sprite sits this far left of centre

const Arrow := preload("res://src/projectiles/Arrow.tscn")

# Charged shots. Holding the shoot button draws the bow (arm held up, a rising creak);
# after Tuning.arrow_charge_time a ping and flash say it's charged, and letting go then
# fires an arrow doing Tuning.arrow_charge_multiplier times the damage. Letting go sooner
# fires a normal arrow. While drawn the player can walk but keeps facing the same way,
# strafing with the bow aimed.
const CHARGE_SOUND := preload("res://assets/sfx/arrow_charge.wav")
const CHARGED_SOUND := preload("res://assets/sfx/arrow_charged.wav")
const CHARGE_SOUND_LENGTH := 0.6 # Seconds; played faster or slower to fit arrow_charge_time
const CHARGE_DB := -6.0
const CHARGED_DB := -2.0
const CHARGED_FLASH := Color(1, 0.9, 0.5)
const CHARGED_ARROW_TINT := Color(1.5, 1.25, 0.6)

# Game feel
const HURT_HITSTOP := 0.08
# A hit that runs the timer out: the game drops to this speed while the timer drains to
# 0:00 (LevelTimer), then the game over starts. FATAL_FALLBACK real seconds is the most
# it waits for the timer.
const FATAL_SLOW_MOTION := 0.2
const FATAL_FALLBACK := 5.0
const HURT_FLASH := Color(1, 0.35, 0.35)
const GHOST_INTERVAL := 0.04 # Seconds between afterimages while rolling
const GHOST_FADE := 0.2
const FEET := Vector2(0, 13) # From the origin to the player's feet
const DUST := Color(0.75, 0.7, 0.6)

# Spin attack. Pressing the sword button swings as usual; holding it on charges a spin
# (a bar fills over Tuning.spin_charge_time, then a ping and a flash), walking at
# Tuning.spin_charge_move of full speed. Letting go once charged spins the whole sprite
# round with the sword out (frame SPIN_FRAME of the slash) over Tuning.spin_duration,
# rooted, hitting every enemy within Tuning.spin_radius (see Enemy.spin_hit). Letting go
# sooner does nothing; a roll, a hit, a daze or drawing the bow drops the charge.
const SPIN_FRAME := 6 # Slash frame with the sword fully out and no swoosh trail
const SPIN_CHARGED_FLASH := Color(1, 0.9, 0.5)
const SPIN_PITCH := 0.8

# Parrying: see Enemy._on_player_sword.
const DIZZY_OFFSET := Vector2(0, -24) # Over the player's head

# Cooldown bars over the head (see StatusBars), above the dizzy stars.
const BARS_OFFSET := Vector2(0, -32)
const SWORD_BAR := Color(0.95, 0.25, 0.25)
const ROLL_BAR := Color(0.4, 0.9, 0.5)
const ARROW_BAR := Color(1, 0.7, 0.25)
const DAZE_BAR := Color(0.75, 0.5, 1)
const SPIN_BAR := Color(1, 0.85, 0.3)
const CURSE_BAR := Color(0.55, 0.85, 0.3) # A warlock's curses (see Curses)
# Special tiles (see SpecialTiles): a speed or slow tile shows a full bar while stood on;
# thermal paste counts down until it dissolves.
const FAST_TILE_BAR := Color(1.0, 0.7, 0.2)
const SLOW_TILE_BAR := Color(0.5, 0.45, 1.0)
const PASTE_BAR := Color(0.85, 0.5, 0.17)
const SPEED_UP_SOUND := preload("res://assets/sfx/tile_speed_up.wav")
const SLOW_DOWN_SOUND := preload("res://assets/sfx/tile_slow_down.wav")
const GROUND_SOUND_DB := -8.0

# 8-bit roll and landing sounds, each picked at random per play.
const ROLL_BLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/movement/roll3.wav"),
]
const LANDINGS: Array[AudioStream] = [
	preload("res://assets/sfx/movement/land1.wav"), preload("res://assets/sfx/movement/land2.wav"),
	preload("res://assets/sfx/movement/land3.wav"), preload("res://assets/sfx/movement/land4.wav"),
	preload("res://assets/sfx/movement/land5.wav"), preload("res://assets/sfx/movement/land6.wav"),
]
const ROLL_DB := -8.0
const ROLL_LAND_DB := -12.0 # Soft thud as a roll ends
const PIT_LAND_DB := -4.0 # Heavier thud dropping back in after a pitfall

# Everything the player pressed this frame. Movement actions share their names with
# the Direction constants.
class FrameInput:
	var move := Vector2.ZERO # Sum of the held directions, not normalised
	var held := "" # First held direction, checked right, left, down, up
	var released := "" # First released direction, same order
	var roll := false # Rolls trigger on press
	var melee := false
	var melee_held := false # Sword button down: charging a spin (see _update_spin_charge)
	var ranged := false # Shoot pressed this frame: starts drawing the bow
	var ranged_held := false # Letting go while able to act looses a drawn arrow
	var acting := false # Read from the controls; false while the player can't act
	var fired := false # Set by _handle_input when an arrow went out this frame

# Pixels/sec. Tuning values (roll, damage, cooldowns and more) are read from Tuning.
var speed: float = Tuning.player_speed
var current_room := Constants.START_ROOM
var direction := Direction.RIGHT # Direction the player is facing

var knockback := Vector2.ZERO
var _slide := Vector2.ZERO # Last frame's walking velocity, carried on slick floor
var _ground_factor := 1.0 # Speed and attack speed from the tile underfoot (_apply_ground)
var _ground_sound: AudioStreamPlayer # Speeding up or slowing down on a tile
var last_tile := Vector2.ZERO # Where the player respawns after falling down a pitfall
var last_velocity := Vector2.ZERO # Walking velocity when the boss-door cutscene started
var _ghost_timer := 0.0
var _roll_sound: AudioStreamPlayer
var _land_sound: AudioStreamPlayer
var _charge_sound: AudioStreamPlayer
var _charged_sound: AudioStreamPlayer

# Bow drawing; see CHARGE_SOUND.
var _charging := false
var _charge_time := 0.0 # Seconds the bow has been drawn
var _charged := false # Drawn for at least Tuning.arrow_charge_time

# Parrying
var swing_started_at := 0 # Ticks (ms) when the current or last sword swing began
var swing_started_frame := -1 # Physics frame the current or last swing began
var _parried_swing := -2 # swing_started_frame of the last swing that parried an enemy
var _daze_timer: Timer # Running while dazed from a blocked swing
var _vulnerable_timer: Timer # Running while the next hit taken is multiplied
var _dizzy: Node2D # Stars shown while dazed
var _sword_cooldown: Timer # Running after a swing ends, until the next one is allowed
var _was_slashing := false # The last physics frame ended mid-swing
# The enemy the player last parried. While it stays stunned, swings skip the sword
# cooldown so the player can finish it off (Tuning.instant_finisher).
var _finisher_target: Enemy
# Status effects from warlocks: inverted controls, lowered stats, daze, a jammed bow.
var curses: Curses

# Spin attack; see SPIN_FRAME.
var _spin_charging := false # Sword button held since a swing
var _spin_charge := 0.0 # Seconds held
var _spin_ready := false # Held for at least Tuning.spin_charge_time
var _spin_timer: Timer # Running while spinning
var _spin_shape: CollisionShape2D # SpinHitbox's circle, live only while spinning
var _spin_tween: Tween
# swing_started_frame of the last swing begun while a group rush was on in this room; see
# is_spin_opener.
var _rush_swing := -2
# Enemies in the group rush under way when the current spin started, 0 if none: a spin
# that catches a rush stuns longer the bigger it was (MeleeEnemy._spin_stun_time).
var spin_rush_size := 0

# Room transitions have two overlapping phases. While auto_walking the player ignores
# input and walks through the doorway until it enters the next room. in_transition lasts
# until the TransitionPause timer (and any boss-door cutscene) ends; enemies freeze meanwhile.
var auto_walking := false
var in_transition := false
# Global centre of the doorway being walked through, or null outside a door transition.
# The auto-walk steers the player's feet onto it so they can't catch on the door frame.
var _door_lane: Variant = null

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var invincibility_cooldown: Timer = $InvincibilityCooldown
# Hit with too little time left: frozen out of acting while the timer drains (lose_time).
var _dying := false
@onready var level_countdown: Timer = $LevelCountdown # Time left to clear the floor
@onready var respawn_cooldown: Timer = $RespawnCooldown # Time spent falling down a pitfall
@onready var rolling: Timer = $Rolling
@onready var roll_cooldown: Timer = $RollCooldown

func _ready() -> void:
	z_index = 2
	Tuning.changed.connect(_on_tuning_changed)
	Juice.add_flash(animator)
	_roll_sound = _add_sound(ROLL_DB)
	_land_sound = _add_sound(PIT_LAND_DB)
	_charge_sound = _add_sound(CHARGE_DB)
	_charge_sound.stream = CHARGE_SOUND
	_charged_sound = _add_sound(CHARGED_DB)
	_charged_sound.stream = CHARGED_SOUND
	_ground_sound = _add_sound(GROUND_SOUND_DB)
	_daze_timer = Timer.new()
	_daze_timer.one_shot = true
	_daze_timer.timeout.connect(Juice.set_grey.bind(animator, false))
	_daze_timer.timeout.connect(_show_dizzy.bind(false))
	add_child(_daze_timer)
	_vulnerable_timer = Timer.new()
	_vulnerable_timer.one_shot = true
	_vulnerable_timer.timeout.connect(_set_vulnerable.bind(false))
	add_child(_vulnerable_timer)
	_sword_cooldown = Timer.new()
	_sword_cooldown.one_shot = true
	add_child(_sword_cooldown)
	curses = Curses.new()
	curses.player = self
	add_child(curses)
	_add_spin_hitbox()
	_add_status_bars()

# Each cooldown counts down in its own bar over the head while it runs.
func _add_status_bars() -> void:
	var bars := StatusBars.new()
	bars.position = BARS_OFFSET
	bars.add_bar(StatusBars.Icon.DAZE, DAZE_BAR, StatusBars.timer_left.bind(_daze_timer))
	bars.add_bar(StatusBars.Icon.SWORD, SWORD_BAR, StatusBars.timer_left.bind(_sword_cooldown))
	bars.add_bar(StatusBars.Icon.ROLL, ROLL_BAR, StatusBars.timer_left.bind(roll_cooldown))
	bars.add_bar(StatusBars.Icon.SPIN, SPIN_BAR, _spin_charge_shown)
	bars.add_bar(StatusBars.Icon.ARROW, ARROW_BAR, StatusBars.timer_left.bind(shoot_cooldown))
	# Curses on top, each with its own icon (daze shows in the daze bar above).
	var curse_icons := {
		Curses.Effect.INVERTED: StatusBars.Icon.INVERTED,
		Curses.Effect.DEFENSE_DOWN: StatusBars.Icon.DEFENSE_DOWN,
		Curses.Effect.ATTACK_DOWN: StatusBars.Icon.ATTACK_DOWN,
		Curses.Effect.SLOW: StatusBars.Icon.SLOW,
		Curses.Effect.JAM: StatusBars.Icon.JAM,
	}
	for effect: Curses.Effect in curse_icons:
		bars.add_bar(curse_icons[effect], CURSE_BAR, curses.left.bind(effect))
	bars.add_bar(StatusBars.Icon.PASTE, PASTE_BAR,
		func() -> float: return SpecialTiles.paste_left_in(Game.room_by_id(current_room), self))
	bars.add_bar(StatusBars.Icon.FAST, FAST_TILE_BAR, func() -> float: return 1.0 if _ground_factor > 1.0 else 0.0)
	bars.add_bar(StatusBars.Icon.SLOW, SLOW_TILE_BAR, func() -> float: return 1.0 if _ground_factor < 1.0 else 0.0)
	add_child(bars)

func _physics_process(delta: float) -> void:
	if !auto_walking:
		# Dazed, down a pitfall, or while the screen is still moving to a new room (the
		# room isn't fully in view yet, so they could walk into a pit they can't see), the
		# player can't move, roll or attack.
		var can_act := _daze_timer.is_stopped() && respawn_cooldown.is_stopped() && !in_transition \
			&& !_dying
		var input := _read_input() if can_act else FrameInput.new()
		_handle_input(input)
		_update_animation(input)
		_update_hitboxes()
	else:
		_cancel_charge()
		animator.speed_scale = 1.0 # Off any speed tile, walking through a door
		_slide = Vector2.ZERO
		if _door_lane != null:
			_steer_through_door()
	if visible:
		move_and_slide()

	# Knockback is moved separately so it doesn't overwrite the movement velocity
	var move_velocity := velocity
	knockback = knockback.move_toward(Vector2.ZERO, 300 * delta)
	_keep_knockback_safe(delta)
	velocity = knockback
	move_and_slide()
	knockback = velocity
	velocity = move_velocity

	_update_respawn_point()
	_update_roll_ghosts(delta)
	_update_sword_cooldown()

# Knockback (from hits and shot recoil) never carries the player into a pit or through a
# doorway. Any axis of this frame's knockback that would newly touch a pit (the FeetBox's
# trigger) or a doorway's transition detector (the RoomDetectionBox's) is dropped, so the
# player slides along the edge instead.
func _keep_knockback_safe(delta: float) -> void:
	if knockback == Vector2.ZERO || auto_walking || !visible:
		return
	var step := knockback * delta
	if _would_trigger(Vector2(step.x, 0)):
		knockback.x = 0
	if _would_trigger(Vector2(knockback.x * delta, step.y)):
		knockback.y = 0

# True if moving by `motion` would bring the FeetBox onto a pit, or the RoomDetectionBox onto
# a doorway detector, that it isn't already touching.
func _would_trigger(motion: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	for area: Area2D in [$FeetBox, $RoomDetectionBox]:
		var shape: CollisionShape2D = area.get_node("CollisionShape2D")
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape.shape
		query.collision_mask = area.collision_mask
		query.collide_with_areas = false # Both areas react to bodies (tile collision)
		query.transform = shape.global_transform
		var touching := {}
		for hit in space.intersect_shape(query):
			touching[[hit.rid, hit.shape]] = true # Tile cells share a body per chunk
		query.transform = shape.global_transform.translated(motion)
		for hit in space.intersect_shape(query):
			if !touching.has([hit.rid, hit.shape]):
				return true
	return false

func _read_input() -> FrameInput:
	var input := FrameInput.new()
	for key in [Direction.RIGHT, Direction.LEFT, Direction.DOWN, Direction.UP]:
		var dir := curses.steer(key) # Swapped while the controls are inverted
		if Input.is_action_pressed(key):
			input.move += Direction.to_vector(dir)
			if input.held == "":
				input.held = dir
		if input.released == "" && Input.is_action_just_released(key):
			input.released = dir
	input.roll = Input.is_action_just_pressed("roll")
	input.melee = Input.is_action_just_pressed("melee_attack")
	input.melee_held = Input.is_action_pressed("melee_attack")
	input.ranged = Input.is_action_just_pressed("ranged_attack")
	input.ranged_held = Input.is_action_pressed("ranged_attack")
	input.acting = true
	return input

# Movement, rolling, attacks and arrows. Runs before _update_animation, so the checks
# here see the animation from the previous frame.
func _handle_input(input: FrameInput) -> void:
	# A jammed bow won't draw; it clicks instead, and no arrow is spent.
	if input.ranged && curses.has(Curses.Effect.JAM):
		input.ranged = false
		curses.jam_feedback()
	# Out of arrows, the shot never happens; the HUD counter shakes instead.
	if input.ranged && Game.arrows <= 0 && !Tuning.infinite_arrows:
		input.ranged = false
		if _action() != Action.DAMAGE && shoot_cooldown.time_left == 0:
			Game.arrows_empty.emit()
			shoot_cooldown.start(Tuning.shoot_cooldown)

	if rolling.time_left == 0:
		velocity = Vector2.ZERO

	if input.roll && rolling.time_left == 0 && roll_cooldown.time_left == 0:
		_end_spin()
		_cancel_spin_charge()
		velocity += Direction.to_vector(direction)
		speed = Tuning.player_speed * Tuning.roll_speed_multiplier
		rolling.start(Tuning.roll_duration)
		_cancel_charge()
		# Rolls pass through enemies (to get behind a knight mid-slash), never walls.
		set_collision_mask_value(Constants.Layer.ENEMY, false)
		hitbox.disabled = true
		hurtbox.disabled = true
		_ghost_timer = 0.0
		_play_random(_roll_sound, ROLL_BLIPS, 0.04)
		Juice.burst(get_parent(), global_position + FEET, DUST, 8, 45.0,
			-Direction.to_vector(direction), 2.0, 0.35)
	elif rolling.time_left == 0:
		var rooted := _action() in [Action.SLASH, Action.SHOOT, Action.DAMAGE] && !_charging
		if !rooted && respawn_cooldown.time_left == 0:
			velocity += input.move
	velocity = velocity.normalized() * speed * curses.speed_multiplier()
	if _spin_charging && rolling.time_left == 0:
		velocity *= Tuning.spin_charge_move
	_apply_ground()

	# Decided once, here: _update_animation can drop a swing back to idle (on its last
	# frame), which mustn't let a new one start that same frame
	# before the cooldown has begun.
	input.melee = input.melee && can_swing()
	if input.melee:
		_cancel_charge() # A swing (say, to parry) puts the bow down
		hitbox.disabled = false
		swing_started_at = Time.get_ticks_msec()
		swing_started_frame = Engine.get_physics_frames()
		if _group_rush_on():
			_rush_swing = swing_started_frame
		Juice.play($Slash)

	_update_spin_charge(input)
	_update_charge(input)

# The special tile underfoot (SpecialTiles) changes this frame's walk or roll: speed and
# slow tiles scale it, along with how fast the player's animations (and so swings) play,
# and on slick floor the velocity eases towards it from the last frame's, so the player
# slides. The sword and bow cooldowns started on such a tile are scaled too (_ground_factor).
func _apply_ground() -> void:
	var frame := SpecialTiles.frame_at(Game.room_by_id(current_room), global_position + FEET)
	var factor := SpecialTiles.speed_factor(frame)
	if factor != _ground_factor && factor != 1.0: # Stepped onto a speed or slow tile
		_ground_sound.stream = SPEED_UP_SOUND if factor > 1.0 else SLOW_DOWN_SOUND
		Juice.play(_ground_sound, 0.04)
	_ground_factor = factor
	velocity *= _ground_factor
	animator.speed_scale = _ground_factor
	if SpecialTiles.is_slick(frame) && rolling.time_left == 0:
		velocity = _slide.move_toward(velocity, Tuning.slick_grip * get_physics_process_delta_time())
	_slide = velocity

# Draws the bow on a press, charges it while held and looses the arrow on release.
# Losing the button any other way (dazed, falling, a room transition) lowers it unfired.
func _update_charge(input: FrameInput) -> void:
	if !_charging:
		if input.ranged && _action() != Action.DAMAGE && shoot_cooldown.time_left == 0 \
				&& !is_invincible():
			_charging = true
			_charge_time = 0.0
			_charged = false
			var rate := CHARGE_SOUND_LENGTH / maxf(Tuning.arrow_charge_time, 0.01)
			Juice.play(_charge_sound, 0.0, clampf(rate, 0.25, 4.0))
		else:
			return
	if !input.ranged_held:
		if input.acting:
			_fire_arrow(_charged)
			input.fired = true
		_cancel_charge()
		return
	_charge_time += get_physics_process_delta_time()
	if !_charged && _charge_time >= Tuning.arrow_charge_time:
		_charged = true
		_charge_sound.stop()
		Juice.play(_charged_sound, 0.02)
		Juice.flash(animator, 0.15, CHARGED_FLASH)
		Juice.burst(get_parent(), global_position, CHARGED_FLASH, 8, 50.0, Vector2.ZERO, 1.5, 0.25)

# Stops drawing the bow without shooting.
func _cancel_charge() -> void:
	if !_charging:
		return
	_charging = false
	_charged = false
	_charge_sound.stop()
	if _action() in [Action.SHOOT, Action.WALKSHOOT] && !animator.is_playing():
		_play(Action.IDLE) # Was held on the drawn pose

func _fire_arrow(charged: bool) -> void:
	var arrow: Projectile = Arrow.instantiate()
	get_parent().add_child(arrow)
	arrow.position = position
	arrow.direction = direction
	arrow.damage = Tuning.arrow_damage * (Tuning.arrow_charge_multiplier if charged else 1.0) \
		* curses.damage_dealt_multiplier()
	arrow.speed = Tuning.arrow_speed
	if charged:
		arrow.modulate = CHARGED_ARROW_TINT
	if !Tuning.infinite_arrows:
		Game.add_arrows(-1)
	shoot_cooldown.start(Tuning.shoot_cooldown / _ground_factor)
	Juice.play($Shoot, 0.08, 0.85 if charged else 1.0)
	var aim := Direction.to_vector(direction)
	knockback = -aim * Tuning.shoot_recoil * (1.5 if charged else 1.0)
	Juice.burst(get_parent(), global_position + aim * 10, Color(1, 0.95, 0.7), 10 if charged else 5,
		60.0, aim, 1.5, 0.15)

# Each check reads the action again, since earlier lines may have changed the animation.
func _update_animation(input: FrameInput) -> void:
	if is_spinning():
		return # The spin holds its own pose
	if _charging:
		_show_drawn_bow(input)
		return
	# Letting go of a direction stops a walk, but never cuts short a swing, shot or flinch.
	if input.released != "" && _action() not in ACTION_END_FRAME:
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
			var before := animator.animation
			_play(Action.WALK)
			# A walk's first frame is the standing pose, so a new walk (or a turn) starts on
			# its first step: even a tap shows a step, and letting go stands back up.
			if animator.animation != before:
				animator.frame = WALK_FIRST_STEP

	if input.melee: # Already checked against can_swing() in _handle_input
		_play(Action.SLASH)

	if input.fired:
		if input.move != Vector2.ZERO:
			_play(Action.WALKSHOOT)
		else:
			_play(Action.SHOOT) # Plays out from the held pose, then back to idle

# Arm up while the bow is drawn: walking with it up, or holding the shoot pose still.
# Facing is locked to where the bow was drawn, so walking strafes instead of turning.
func _show_drawn_bow(input: FrameInput) -> void:
	if input.move != Vector2.ZERO && rolling.time_left == 0:
		_play(Action.WALKSHOOT)
	else:
		var pose := ACTION_NAMES[Action.SHOOT] + "_" + direction
		if animator.animation != pose:
			animator.play(pose)
		animator.pause()
		animator.frame = 0

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

# Not rolling, mid-swing or flinching, and the cooldown after the last swing has run out
# (or a parried enemy is still stunned). No swinging out of a roll: its invincibility would
# let the player hit from behind an enemy that's turning round to strike them. None while
# invincible after a hit either, or the player could trade into an enemy for free.
func can_swing() -> bool:
	if rolling.time_left > 0 || is_invincible():
		return false
	return _action() not in [Action.SLASH, Action.DAMAGE] && (_sword_cooldown.is_stopped() || in_finisher())

# Roughly how long until the sword can be out again: what's left of a swing under way plus
# the cooldown after it. A new swing's hitbox is on from its first frame. Wizards use it to
# tell whether a fireball they bat back could be returned in time (RangedEnemy._try_deflect).
func seconds_until_can_swing() -> float:
	var cooldown := 0.0 if in_finisher() else _sword_cooldown.time_left
	if _action() == Action.SLASH:
		var fps := animator.sprite_frames.get_animation_speed(animator.animation) * absf(animator.speed_scale)
		var frames_left := maxi(ACTION_END_FRAME[Action.SLASH] - animator.frame, 0)
		var swing_left := frames_left / fps if fps > 0 else 0.0
		cooldown = swing_left + (0.0 if in_finisher() else Tuning.sword_cooldown)
	return cooldown

# In the invincibility after being hit (or falling down a pitfall); no attacking till it ends.
func is_invincible() -> bool:
	return invincibility_cooldown.time_left > 0

# Called when the player parries `enemy`: until its stun wears off (or it dies), swings
# come out with no cooldown between them.
func start_finisher(enemy: Enemy) -> void:
	if Tuning.instant_finisher:
		_finisher_target = enemy
		_sword_cooldown.stop()

func in_finisher() -> bool:
	return Tuning.instant_finisher && is_instance_valid(_finisher_target) && _finisher_target.is_stunned()

# Starts the sword cooldown as a swing ends, however it ends: finished, blocked, or cut
# short by a hit or a roll.
func _update_sword_cooldown() -> void:
	var slashing := _action() == Action.SLASH
	if _was_slashing && !slashing:
		if Tuning.sword_cooldown > 0 && !in_finisher():
			_sword_cooldown.start(Tuning.sword_cooldown / _ground_factor)
	_was_slashing = slashing

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
# Returns whether the hit landed (false while invincible).
func take_damage(damage: float, from_direction: String, mute: bool) -> bool:
	if _dying:
		return false # Already done for; the timer is showing it
	if invincibility_cooldown.time_left == 0:
		invincibility_cooldown.start(Tuning.hurt_invincibility)
		animator.modulate.a = 0.5
		Juice.flash(animator, 0.15, HURT_FLASH)

		if from_direction != "":
			_cancel_charge()
			_end_spin()
			_cancel_spin_charge()
			_play(Action.DAMAGE, from_direction)
			knockback = Direction.to_vector(from_direction) * Tuning.player_knockback
			Juice.hitstop(HURT_HITSTOP)
			Juice.shake(Juice.SHAKE_MEDIUM)
			Juice.burst(get_parent(), global_position, Color(0.8, 0.1, 0.1), 8, 70.0,
				Direction.to_vector(from_direction))

		if !mute:
			Juice.play($Hit, 0.05)

		# Pitfall falls (no direction) aren't hits, so they don't use up a vulnerability.
		if from_direction != "" && is_vulnerable():
			damage *= Tuning.stagger_damage_multiplier
			_set_vulnerable(false)
		damage *= curses.damage_taken_multiplier() # Lowered defense
		lose_time(damage * Tuning.seconds_per_damage)
		return true
	return false

# Damage comes off the level timer, in whole seconds (at least one). Running it out ends
# the run, as the timer reaching zero on its own does.
func lose_time(seconds: float) -> void:
	if Tuning.god_mode || level_countdown.is_stopped():
		return
	var lost := maxf(ceilf(seconds - 0.001), 1.0)
	var left := level_countdown.time_left - lost
	if left > 0:
		Game.time_lost.emit(lost, false)
		level_countdown.start(left)
		return
	# A killing hit: slow motion while the timer drains to 0:00, then the game over.
	_dying = true
	Juice.slow_motion(FATAL_SLOW_MOTION)
	Game.time_lost.emit(lost, true) # Before stopping, so the timer drains from the old time
	level_countdown.stop()
	Game.fatal_countdown_finished.connect(_finish_dying, CONNECT_ONE_SHOT)
	get_tree().create_timer(FATAL_FALLBACK, true, false, true).timeout.connect(_finish_dying)

# The timer has landed on 0:00 (or it took too long): normal speed, and game over.
func _finish_dying() -> void:
	if !_dying:
		return
	_dying = false
	if Game.fatal_countdown_finished.is_connected(_finish_dying):
		Game.fatal_countdown_finished.disconnect(_finish_dying)
	Juice.end_time_effects() # Or the game over's timers would run slow
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
	var first := Vector2i.ONE * Room.FLOOR_FIRST
	var cell := tiles.local_to_map(local).clamp(first, Vector2i.ONE * room.floor_last)
	# Never on a trap or teleporter: cracked floor in particular would still be a hole.
	if tiles.get_cell_source_id(0, cell) != -1 && room.is_safe_ground(cell):
		last_tile = room.position + tiles.map_to_local(cell) + RESPAWN_OFFSET

# A sound player made in code for the roll and landing sounds, which swap streams each play.
func _add_sound(volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.volume_db = volume_db
	add_child(sound)
	return sound

func _play_random(sound: AudioStreamPlayer, streams: Array[AudioStream], spread: float,
		base := 1.0) -> void:
	sound.stream = streams.pick_random()
	Juice.play(sound, spread, base)

# Leaves fading copies of the current frame behind while rolling.
func _update_roll_ghosts(delta: float) -> void:
	if rolling.time_left == 0 || !visible:
		return
	_ghost_timer -= delta
	if _ghost_timer > 0:
		return
	_ghost_timer = GHOST_INTERVAL
	var ghost := Sprite2D.new()
	ghost.texture = animator.sprite_frames.get_frame_texture(animator.animation, animator.frame)
	ghost.centered = animator.centered
	ghost.offset = animator.offset
	ghost.flip_h = animator.flip_h
	ghost.scale = animator.scale
	ghost.modulate = Color(0.6, 0.8, 1.0, 0.45)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	ghost.global_position = animator.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	tween.tween_callback(ghost.queue_free)

# Walk speed changes apply at once, unless mid-roll (the roll's end eases back to it).
func _on_tuning_changed(key: String) -> void:
	if key == "player_speed" && rolling.time_left == 0 && speed != 0:
		speed = Tuning.player_speed

func _on_level_countdown_timeout() -> void:
	die()

func _on_hurtbox_area_shape_entered(_area_id: RID, area: Area2D, _area_shape: int, _self_shape: int) -> void:
	if respawn_cooldown.time_left > 0: # Down a pitfall
		return
	if (area.get_name() == "Hitbox" && area.get_parent().get_parent().animator.visible == true):
		var attacker: Node = area.get_parent().get_parent()
		# A wizard's staff hits for its own melee damage; `damage` is its fireballs'.
		var amount: float = attacker.melee_damage() if attacker.has_method("melee_damage") else attacker.damage
		if take_damage(amount, attacker.direction, false) && attacker.has_method("landed_hit"):
			attacker.landed_hit() # A troll's hit steals coins
	elif area.get_name() == "ProjectileHitbox":
		var shot: Projectile = area.get_parent()
		if shot.deflectable:
			_take_deflectable_hit.call_deferred(shot)
		else:
			take_damage(shot.damage, shot.direction, false)

# A deflectable shot touched the hurtbox. Waits for the end of the frame, by when the shot
# has decided whether the sword touching it this frame sent it back.
func _take_deflectable_hit(shot: Projectile) -> void:
	if is_instance_valid(shot) && shot.hostile_to_player && !_sword_is_on(shot):
		take_damage(shot.damage, shot.direction, false)

func _sword_is_on(shot: Projectile) -> bool:
	return is_slashing() && $HitboxPivot/Hitbox.overlaps_area(shot.get_node("ProjectileHitbox"))

# Mid-swing with the sword out.
func is_slashing() -> bool:
	return _action() == Action.SLASH && !hitbox.disabled

# The current swing parried an enemy. Any other enemy the same swing catches lets it pass
# through instead of blocking it (see Enemy._block_player_swing), so a good parry is never
# undone by the blade clipping a bystander.
func mark_swing_parried() -> void:
	_parried_swing = swing_started_frame

# The swing that began on physics frame `swing_frame` parried an enemy.
func swing_parried(swing_frame: int) -> bool:
	return _parried_swing == swing_frame

# The swing begun on `swing_frame` is the start of a spin against a group rush: it began
# while enemies were rushing in together (AttackCoordinator), and the button is still
# held, charging. Such a swing isn't blocked or guarded against (see
# Enemy._block_player_swing, MeleeEnemy._guard): it passes through, no stagger, chip or
# counter, so the charge carries on. A tap let go of before it lands is judged as usual.
func is_spin_opener(swing_frame: int) -> bool:
	return swing_frame == _rush_swing && _spin_charging

func _group_rush_on() -> bool:
	return _group_rush_size() > 0

# Enemies in the group rush under way in this room, 0 if none.
func _group_rush_size() -> int:
	var room := Game.room_by_id(current_room)
	if room == null:
		return 0
	var coordinator := room.get_node_or_null(AttackCoordinator.NODE_NAME) as AttackCoordinator
	return coordinator.rusher_count() if coordinator != null else 0

# An enemy blocked a swing made too early, before its twinkle: the swing ends, the
# player is dazed (can't act) for a moment, and their next hit taken is multiplied.
func stagger() -> void:
	daze(Tuning.blocked_daze_time)
	_set_vulnerable(true)

# Can't act for `seconds` (or longer, if already dazed for longer): greyed out, with stars.
func daze(seconds: float) -> void:
	_end_spin()
	_cancel_spin_charge()
	_play(Action.IDLE)
	hitbox.set_deferred("disabled", true) # Called from a collision callback
	velocity = Vector2.ZERO
	_daze_timer.start(maxf(seconds, _daze_timer.time_left))
	Juice.set_grey(animator, true) # Greyed out while dazed, to show the player can't act
	_show_dizzy(true)

# --- Spin attack (see SPIN_FRAME) ---

func is_spinning() -> bool:
	return !_spin_timer.is_stopped()

# What a spin hit does, after any lowered-attack curse.
func spin_damage() -> float:
	return Tuning.spin_damage * curses.damage_dealt_multiplier()

# A circle round the player named SpinHitbox, on the player's layer looking for enemies;
# an enemy's hurtbox takes it as a spin hit (Enemy._on_hurtbox_area_shape_entered).
func _add_spin_hitbox() -> void:
	var area := Area2D.new()
	area.name = "SpinHitbox"
	area.collision_layer = 1 << (Constants.Layer.PLAYER - 1)
	area.collision_mask = 1 << (Constants.Layer.ENEMY - 1)
	area.monitoring = false # Enemies' hurtboxes do the noticing
	add_child(area)
	_spin_shape = CollisionShape2D.new()
	_spin_shape.shape = CircleShape2D.new()
	_spin_shape.disabled = true
	area.add_child(_spin_shape)
	_spin_timer = Timer.new()
	_spin_timer.one_shot = true
	_spin_timer.timeout.connect(_end_spin)
	add_child(_spin_timer)

# Charging starts with a swing and goes on while the button stays down; letting go
# charged spins.
func _update_spin_charge(input: FrameInput) -> void:
	if is_spinning():
		return
	if input.melee:
		_spin_charging = true
		_spin_charge = 0.0
		_spin_ready = false
		return
	if !_spin_charging:
		return
	if !input.melee_held:
		var spin := input.acting && _spin_ready
		_cancel_spin_charge()
		if spin:
			_start_spin()
		return
	if rolling.time_left > 0 || _action() == Action.DAMAGE || _charging:
		_cancel_spin_charge()
		return
	_spin_charge += get_physics_process_delta_time()
	if !_spin_ready && _spin_charge >= Tuning.spin_charge_time:
		_spin_ready = true
		Juice.play(_charged_sound, 0.02, 1.2)
		Juice.flash(animator, 0.15, SPIN_CHARGED_FLASH)
		Juice.burst(get_parent(), global_position, SPIN_CHARGED_FLASH, 8, 50.0, Vector2.ZERO, 1.5, 0.25)

func _cancel_spin_charge() -> void:
	_spin_charging = false
	_spin_charge = 0.0
	_spin_ready = false

# How full the charge bar over the head is; empty unless charging.
func _spin_charge_shown() -> float:
	if !_spin_charging || Tuning.spin_charge_time <= 0:
		return 0.0
	return minf(_spin_charge / Tuning.spin_charge_time, 1.0)

# Round once with the sword out: a temporary look, the slash's extended frame spun whole.
func _start_spin() -> void:
	spin_rush_size = _group_rush_size()
	_spin_timer.start(Tuning.spin_duration)
	hitbox.set_deferred("disabled", true)
	_play(Action.SLASH)
	animator.pause()
	animator.frame = mini(SPIN_FRAME, animator.sprite_frames.get_frame_count(animator.animation) - 1)
	(_spin_shape.shape as CircleShape2D).radius = Tuning.spin_radius / absf(scale.x)
	_spin_shape.set_deferred("disabled", false)
	Juice.play($Slash, 0.05, SPIN_PITCH)
	Juice.burst(get_parent(), global_position, Color(1, 0.95, 0.7), 12, 90.0, Vector2.ZERO, 1.5, 0.25)
	var turn := -TAU if direction == Direction.LEFT else TAU # Sweeping the way the blade points
	animator.rotation = 0.0
	_spin_tween = create_tween()
	_spin_tween.tween_property(animator, "rotation", turn, Tuning.spin_duration)

# The spin is over, or cut short (a hit, a roll, a daze): upright, blade put away.
func _end_spin() -> void:
	var was_spinning := _spin_tween != null
	_spin_timer.stop()
	if _spin_tween != null:
		_spin_tween.kill()
		_spin_tween = null
	animator.rotation = 0.0
	_spin_shape.set_deferred("disabled", true)
	if was_spinning && _action() == Action.SLASH:
		_play(Action.IDLE) # The sword cooldown starts from here (_update_sword_cooldown)

# What a sword hit does, after any lowered-attack curse.
func sword_damage() -> float:
	return Tuning.sword_damage * curses.damage_dealt_multiplier()

func is_dazed() -> bool:
	return !_daze_timer.is_stopped()

func is_vulnerable() -> bool:
	return !_vulnerable_timer.is_stopped()

func _set_vulnerable(on: bool) -> void:
	if on:
		_vulnerable_timer.start(Tuning.stagger_vulnerable_time)
	else:
		_vulnerable_timer.stop()

func _show_dizzy(on: bool) -> void:
	if is_instance_valid(_dizzy):
		_dizzy.queue_free()
	if on:
		_dizzy = Juice.dizzy(self, DIZZY_OFFSET)

func _on_invincibility_cooldown_timeout() -> void:
	animator.modulate.a = 1

# Stepped onto a pitfall. A roll carries the player over it; they only fall if the roll
# ends with their feet still over a pit (see _on_rolling_timeout).
func _on_feet_box_body_entered(_body: Node2D) -> void:
	if rolling.time_left == 0:
		_fall()

func _fall() -> void:
	if respawn_cooldown.time_left == 0:
		$Fall.play()
		visible = false
		knockback = Vector2.ZERO
		_slide = Vector2.ZERO
		# A swing cut short by the fall ends now, so its hitbox can't hit while down there.
		_play(Action.IDLE)
		hitbox.set_deferred("disabled", true) # Called from a collision callback
		Game.room_by_id(current_room).player_active = false
		respawn_cooldown.start(1.1)

func _on_respawn_cooldown_timeout() -> void:
	visible = true
	Game.room_by_id(current_room).player_active = true
	position = last_tile
	take_damage(Tuning.pitfall_damage, "", true)
	_land_sound.volume_db = PIT_LAND_DB
	_play_random(_land_sound, LANDINGS, 0.05)
	Juice.burst(get_parent(), global_position + FEET, DUST, 10, 40.0, Vector2.ZERO, 2.0, 0.4)

func _on_rolling_timeout() -> void:
	create_tween().tween_property(self, "speed", Tuning.player_speed, 0.25) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_play(Action.IDLE)
	Juice.burst(get_parent(), global_position + FEET, DUST, 5, 30.0, Vector2.ZERO, 1.5, 0.3)
	_land_sound.volume_db = ROLL_LAND_DB
	_play_random(_land_sound, LANDINGS, 0.08, 1.15)
	set_collision_mask_value(Constants.Layer.ENEMY, true)
	_push_out_of_enemies()
	hitbox.disabled = false
	hurtbox.disabled = false
	roll_cooldown.start(Tuning.roll_cooldown)
	# Came up short of the far side of a gap
	if $FeetBox.has_overlapping_bodies():
		_fall()

# Rolls pass through enemies, so one can end with the player's feet inside an enemy's,
# where turning enemy collision back on wouldn't move them. Nudges them out the shortest
# way that's clear (no wall, enemy, pit or doorway), one enemy at a time, since a nudge out
# of one can land in another. If no way out is clear they stay put.
func _push_out_of_enemies() -> void:
	for i in PUSH_OUT_TRIES:
		var push := _enemy_push()
		if push == Vector2.ZERO:
			return
		global_position += push

# The nudge out of the first enemy the player's feet overlap, or ZERO if none (or no clear
# way out).
func _enemy_push() -> Vector2:
	var feet: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = feet.global_transform
	query.collision_mask = 1 << (Constants.Layer.ENEMY - 1)
	var mine := _shape_rect(feet)
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var body := hit.collider as CollisionObject2D
		if body == null:
			continue
		var theirs_shape := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape2D
		if theirs_shape == null || !(theirs_shape.shape is RectangleShape2D):
			continue
		var theirs := _shape_rect(theirs_shape)
		if !mine.intersects(theirs):
			continue
		var ways: Array[Vector2] = [
			Vector2(theirs.end.x - mine.position.x + PUSH_OUT_GAP, 0),
			Vector2(theirs.position.x - mine.end.x - PUSH_OUT_GAP, 0),
			Vector2(0, theirs.end.y - mine.position.y + PUSH_OUT_GAP),
			Vector2(0, theirs.position.y - mine.end.y - PUSH_OUT_GAP),
		]
		ways.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
		for way in ways:
			if _clear_at(way):
				return way
		return Vector2.ZERO
	return Vector2.ZERO

# The player could stand `offset` from here: their feet touch no wall or enemy, and they
# wouldn't step onto a pit or into a doorway.
func _clear_at(offset: Vector2) -> bool:
	var feet: CollisionShape2D = $CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = feet.global_transform.translated(offset)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	return space.intersect_shape(query, 1).is_empty() && !_would_trigger(offset)

# Global rectangle a RectangleShape2D covers (shapes here are never rotated).
static func _shape_rect(shape: CollisionShape2D) -> Rect2:
	var size := (shape.shape as RectangleShape2D).size * shape.global_scale.abs()
	return Rect2(shape.global_position - size / 2, size)

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
		_door_lane = _doorway_centre()
		# Going through a top door (leaving up, or arriving from above after a bottom door),
		# pass under its arch, which otherwise sits behind everything on the floor.
		if direction == Direction.UP || direction == Direction.DOWN:
			_set_arches_in_front(true)

# Walks the player out through the nearest door, along the axis it's furthest from the room centre.
func start_transition() -> void:
	if velocity == Vector2.ZERO:
		velocity = last_velocity
		move_and_slide()
	var room := Game.room_by_id(current_room)
	var room_center := room.position + room.centre
	# Which side of the centre the player is on picks the door, not which way they were
	# moving: a knockback can carry a player who is walking the other way into a doorway.
	if current_room == Constants.START_ROOM || abs(position.x - room_center.x) > abs(position.y - room_center.y):
		direction = Direction.RIGHT if position.x > room_center.x else Direction.LEFT
	else:
		direction = Direction.DOWN if position.y > room_center.y else Direction.UP
	velocity = Direction.to_vector(direction) * speed
	_play(Action.WALK)
	move_and_slide()

	$TransitionPause.start(TRANSITION_PAUSE[direction])

func end_transition() -> void:
	in_transition = false

# Global centre of the doorway the player is walking out through, picked by direction.
func _doorway_centre() -> Vector2:
	var door: Room.Door
	match direction:
		Direction.RIGHT: door = Room.Door.RIGHT
		Direction.LEFT: door = Room.Door.LEFT
		Direction.UP: door = Room.Door.TOP
		_: door = Room.Door.BOTTOM
	var room := Game.room_by_id(current_room)
	return room.tiles.to_global(room.tiles.map_to_local(room.door_cells[door]))

# Keeps the auto-walk going through a doorway. Sliding into the frame zeroes the velocity,
# which would leave the player stuck there, so it is set afresh every frame: full speed
# out through the door, plus a sideways pull that centres the feet on the doorway.
func _steer_through_door() -> void:
	var ahead := Direction.to_vector(direction)
	var feet: Vector2 = $CollisionShape2D.global_position
	var off: Vector2 = _door_lane - feet
	var across := off - ahead * off.dot(ahead) # The part of the offset across the doorway
	velocity = ahead * speed + (across * DOOR_PULL).limit_length(speed)

# Both rooms a top door joins draw their part of it, so every room's arch is moved.
func _set_arches_in_front(in_front: bool) -> void:
	for room: Room in Game.overworld.rooms_by_id.values():
		room.set_arch_in_front(in_front)

# Entered the next room
func _on_room_detector_area_entered(area: Area2D) -> void:
	current_room = area.get_parent().room_id
	auto_walking = false
	_door_lane = null
	_set_arches_in_front(false)
	_play(Action.IDLE)
	Game.room_entered.emit(current_room)

func _on_transition_pause_timeout() -> void:
	transition_pause_finished.emit()
