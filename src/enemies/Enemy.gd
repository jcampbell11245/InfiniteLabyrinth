class_name Enemy
extends CharacterBody2D

# Shared code for everything the player can fight. Subclasses decide how to move and
# attack; this handles facing, knockback, taking hits and dying.
#
# An enemy lives directly under its Room and only acts while the player is in that room.
# Animations are named "<action>_<direction>", e.g. "slash_left".

signal died(enemy: Enemy)

const KNOCKBACK_FRICTION := 200 # Pixels/sec lost per second
const CLOSE_RANGE := 25 # Pixels on either axis

@export var speed: float
@export var knockback_speed: float
@export var damage: float # Read by the player when this enemy's Hitbox touches it
@export var health: float
@export var attack_frame: int # Attack animation frame the hit or shot happens on
@export var attack_end_frame: int # Attack animation frame that returns to idle
@export var attack_cooldown_length: float
# Parrying. The attack animation freezes on its last windup frame (the one before
# attack_frame) for a random windup hold, rolled within this range each attack. Then a
# twinkle shows and the enemy holds Tuning.parry_window longer before striking. A sword hit in
# that window parries; one before the twinkle is blocked and staggers the player; one
# after it is too late (see _on_player_sword). Both 0 means no hold, twinkle or parrying.
@export var windup_hold_min := 0.0
@export var windup_hold_max := 0.0
# Where the twinkle appears: x pixels out in the facing direction, y pixels down
# (negative is up). Relative to the enemy's origin, before its scale.
@export var twinkle_offset := Vector2(10, -8)
# Where the dizzy stars circle while stunned after being parried.
@export var dizzy_offset := Vector2(0, -20)
@export var invincibility_time := 0.3 # Seconds after a hit before the next one counts
@export var coin_reward := 0 # Coins per floor number
@export var blood_color := Color(0.55, 0.08, 0.08) # Hit particles and the stain left on death
# Closest the enemy's origin gets to a side wall, in pixels. The side walls are drawn over
# everything standing next to them, so a sprite much wider than its feet would vanish into
# them; this keeps it clear. 0 lets the feet touch the wall.
@export var side_wall_margin := 0.0

var direction := "" # Direction facing; "" until first set
var knockback := Vector2.ZERO
var critical_chance := 0
var _windup_held := false # The current attack has reached its windup hold
var _next_hold := -1.0 # Seconds of windup hold for the next attack instead of a random roll; -1 rolls
# The attack under way can't be parried (see _on_player_sword): set by a subclass as it
# starts the attack, cleared once the attack animation ends.
var _unparryable := false
# Physics frame the attack under way started; -1 outside one. A player swing begun before
# this was already coming and just hits (see _swung_first).
var _attack_started_frame := -1
var _twinkled_at := -1 # Ticks (ms) the current attack's twinkle showed; -1 before it does
var _twinkle_timer: Timer # Counts down the random part of the windup hold
var _parry_timer: Timer # Running while the parry window is open
var _stun_timer: Timer # Running while stunned from being parried
var _vulnerable_timer: Timer # Running while the next hit taken is multiplied
var _dizzy: Node2D # Stars shown while stunned
# Parries landed on the attack under way, as a share of those needed to stagger it: 1 after
# a single attack's parry, 0.5 then 1 for a double attack's two. Back to 0 once the attack
# ends unstaggered, or the stun wears off.
var _parry_progress := 0.0
# The scene's own values, before Tuning's enemy multipliers.
var _base := {}
var _health_multiplier := 1.0 # Tuning.enemy_health_multiplier last applied to health

@onready var player: Player = Game.player
@onready var room: Room = get_parent()
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var hurtbox: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var invincibility_cooldown: Timer = $InvincibilityCooldown

# Hit feedback, scaled up for kills and crits. Seconds of hit-stop.
const HITSTOP_HIT := 0.05
const HITSTOP_KILL := 0.09
const HITSTOP_CRIT := 0.12
const HITSTOP_BLOCK := 0.03
# The parry window, parried stun and knockback, sword damage and crit roll are in Tuning.
const PARRY_SPARK := Color(1, 0.95, 0.7)
const TWINKLE_COLOR := Color(1, 0.95, 0.7)
const UNPARRYABLE_TWINKLE_COLOR := Color(1, 0.2, 0.15) # Warns that the attack can't be parried
const PARRY_HITSTOP := 0.1
const FEET_OFFSET := Vector2(0, 8) # From the origin down to where the enemy stands
# Bars over the head (see StatusBars): how far the player is through parrying the attack
# under way, and once parried, the stun counting down.
const BARS_ABOVE_DIZZY := Vector2(0, -8)
const PARRY_BAR := Color(1, 0.85, 0.2)
const STUN_BAR := Color(0.75, 0.5, 1)

func _ready() -> void:
	critical_chance = SaveData.damage_level
	add_to_group("enemies")
	for key: String in ["speed", "damage", "knockback_speed", "attack_cooldown_length", "windup_hold_min", "windup_hold_max"]:
		_base[key] = get(key)
	apply_tuning()
	Tuning.changed.connect(_on_tuning_changed)
	Juice.add_flash(animator)
	_twinkle_timer = _add_timer(_twinkle)
	_parry_timer = _add_timer(_end_windup_hold)
	_stun_timer = _add_timer(_show_dizzy.bind(false))
	_stun_timer.timeout.connect(_reset_parry_progress)
	_vulnerable_timer = _add_timer(_set_vulnerable.bind(false))
	_add_status_bars()
	_remember_spawn.call_deferred() # After subclasses' _ready have set their facing

func _add_status_bars() -> void:
	var bars := StatusBars.new()
	bars.position = dizzy_offset + BARS_ABOVE_DIZZY
	bars.add_bar(StatusBars.Icon.DAZE, STUN_BAR, StatusBars.timer_left.bind(_stun_timer))
	bars.add_bar(StatusBars.Icon.PARRY, PARRY_BAR, func() -> float: return _parry_progress)
	add_child(bars)

func _reset_parry_progress() -> void:
	_parry_progress = 0.0

# Where and how the enemy started, for reset_to_spawn.
var _spawn_position: Vector2
var _spawn_direction := ""
var _spawn_animation: StringName
var _spawn_z_index := 0

func _remember_spawn() -> void:
	_spawn_position = position
	_spawn_direction = direction
	_spawn_animation = animator.animation
	_spawn_z_index = z_index

# The player left the room with this enemy still alive (called once the room has faded to
# black): back to where and how it started, mid-attack, stun and knockback all dropped.
# Health is kept.
func reset_to_spawn() -> void:
	position = _spawn_position
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	direction = _spawn_direction
	z_index = _spawn_z_index
	_end_windup_hold()
	_next_hold = -1.0
	_unparryable = false
	_stun_timer.stop()
	_show_dizzy(false)
	_reset_parry_progress()
	_set_vulnerable(false)
	attack_cooldown.stop()
	_on_reset()
	animator.play(_spawn_animation)

# Subclass state to clear in reset_to_spawn.
func _on_reset() -> void:
	pass

func _on_tuning_changed(key: String) -> void:
	if key.begins_with("enemy_") || key == "freeze_enemies":
		apply_tuning()

# Applies Tuning's enemy multipliers to the scene's values. Health keeps its share of the
# maximum: a half-dead enemy stays half dead when the multiplier changes.
func apply_tuning() -> void:
	speed = _base.speed * Tuning.enemy_speed_multiplier
	damage = _base.damage * Tuning.enemy_damage_multiplier
	knockback_speed = _base.knockback_speed * Tuning.enemy_knockback_multiplier
	attack_cooldown_length = _base.attack_cooldown_length * Tuning.enemy_attack_cooldown_multiplier
	windup_hold_min = _base.windup_hold_min * Tuning.enemy_windup_multiplier
	windup_hold_max = _base.windup_hold_max * Tuning.enemy_windup_multiplier
	if windup_hold_max <= 0 && _base.windup_hold_max > 0:
		windup_hold_max = 0.001 # Still parryable, with no hold before the twinkle
	health *= Tuning.enemy_health_multiplier / _health_multiplier
	_health_multiplier = Tuning.enemy_health_multiplier
	process_mode = Node.PROCESS_MODE_DISABLED if Tuning.freeze_enemies else Node.PROCESS_MODE_INHERIT

# A one-shot timer child, made in code so the scenes don't need one.
func _add_timer(on_timeout := Callable()) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	if on_timeout.is_valid():
		timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer

# amount is the health a normal hit takes; a critical hit decides its own.
func take_damage(from_direction: String, amount: float) -> void:
	if invincibility_cooldown.time_left != 0:
		return
	knockback = Direction.to_vector(from_direction) * knockback_speed * Tuning.hit_knockback
	var hit_dir := Direction.to_vector(from_direction)
	if !is_vulnerable() && _blocks_hit():
		# Sparks fly back towards the attacker.
		Juice.burst(room, global_position - hit_dir * 6, Color(1, 0.9, 0.5), 6, 70.0, -hit_dir, 1.5, 0.25)
		Juice.hitstop(HITSTOP_BLOCK)
		Juice.shake(Juice.SHAKE_LIGHT)
		_chip(hit_dir)
		return

	# Interrupts an attack. Faces the direction the hit travels in, not the attacker.
	if _animation_is("slash") && _hit_interrupts_attack():
		_end_windup_hold()
		_play("idle", from_direction)
	
	hurtbox.set_deferred("disabled", true) # Called from a collision callback
	invincibility_cooldown.start(invincibility_time)
	animator.modulate.a = 0.5
	
	if is_vulnerable():
		amount *= Tuning.stagger_damage_multiplier
		_set_vulnerable(false)
	var critical := _roll_critical()
	_lose_health(amount, critical)
	_hit_feedback(hit_dir, critical, health <= 0)
	if health <= 0:
		die()
	_after_hit()

# A blocked hit still wears the blocker down: Tuning.chip_damage off its health, with no
# invincibility, crit or stagger bonus. It can finish an enemy off. Call after the block's
# own feedback.
func _chip(hit_dir: Vector2) -> void:
	if Tuning.chip_damage <= 0 || health <= 0:
		return
	health -= Tuning.chip_damage
	if health <= 0.0001: # Repeated small chips leave float error behind
		health = 0
		_hit_feedback(hit_dir, false, true)
		die()

# Flash, spray, freeze and shake, harder for kills and crits.
func _hit_feedback(hit_dir: Vector2, critical: bool, killed: bool) -> void:
	Juice.flash(animator)
	Juice.burst(room, global_position, blood_color, 8, 80.0, hit_dir)
	if critical:
		Juice.burst(room, global_position, Color.WHITE, 10, 110.0, Vector2.ZERO, 2.0, 0.3)
		Juice.hitstop(HITSTOP_CRIT)
		Juice.shake(Juice.SHAKE_HEAVY)
	elif killed:
		Juice.hitstop(HITSTOP_KILL)
		Juice.shake(Juice.SHAKE_MEDIUM)
	else:
		Juice.hitstop(HITSTOP_HIT)
		Juice.shake(Juice.SHAKE_LIGHT)

func die() -> void:
	Juice.burst(room, global_position, blood_color, 18, 100.0, Vector2.ZERO, 3.0, 0.5)
	Juice.splat(room, global_position + FEET_OFFSET, blood_color.darkened(0.1))
	Juice.drop_coins(room, global_position, roundi(coin_reward * _coin_multiplier()))
	if randf() < Tuning.arrow_drop_chance:
		Juice.drop_arrows(room, global_position, randi_range(1, Tuning.arrow_drop_max))
	died.emit(self)
	queue_free()

func is_player_in_room() -> bool:
	return player.current_room == room.room_id

# --- Overridable hooks ---

# True when a hit should be shrugged off (any Tuning.hit_knockback still applies).
func _blocks_hit() -> bool:
	return false

func _roll_critical() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(0, Tuning.crit_roll_max) < critical_chance

func _lose_health(amount: float, critical: bool) -> void:
	if critical || Tuning.one_hit_kills:
		health = 0
	else:
		health -= amount

func _after_hit() -> void:
	pass

# Whether a hit that lands mid-attack cuts the attack short.
func _hit_interrupts_attack() -> bool:
	return true

# Just parried (already idle and stunned); show it.
func _on_staggered() -> void:
	pass

# Coins are coin_reward times "floor.looting": floor 1 with no looting is x1.0, floor 1 with
# looting 1 is x1.1, floor 2 with looting 3 is x2.3. Looting tops out at 9, one decimal digit.
func _coin_multiplier() -> float:
	return (Game.overworld.floor_number + SaveData.looting_level / 10.0) * Tuning.coin_multiplier

# --- Helpers for subclasses ---

func _to_player() -> Vector2:
	return player.global_position - global_position

func _is_player_far() -> bool:
	var offset := _to_player()
	return abs(offset.x) > CLOSE_RANGE || abs(offset.y) > CLOSE_RANGE

func _is_player_mostly_horizontal() -> bool:
	var offset := _to_player()
	return abs(offset.x) > abs(offset.y)

func _face_player_horizontally() -> void:
	direction = Direction.LEFT if _to_player().x < 0 else Direction.RIGHT

# Facing up draws the enemy in front of the player, facing down behind.
func _face_player_vertically(z_facing_down := 1) -> void:
	if _to_player().y < 0:
		direction = Direction.UP
		z_index = 10
	else:
		direction = Direction.DOWN
		z_index = z_facing_down

func _animation_is(action: String) -> bool:
	return String(animator.animation).begins_with(action)

func _play(action: String, dir := direction) -> void:
	animator.play(action + "_" + dir)

# --- Parrying ---

enum Parry { NONE, EARLY, IN_WINDOW, LATE }

# How a player sword hit landing now counts against this enemy's attack. Timed from
# when the player started the swing, not when it connects.
func _parry_timing() -> Parry:
	if windup_hold_max <= 0 || !_animation_is(_attack_action()):
		return Parry.NONE
	if animator.frame > attack_frame: # Already struck; recovering
		return Parry.NONE
	if _swung_first():
		return Parry.NONE
	if _twinkled_at < 0 || player.swing_started_at < _twinkled_at:
		return Parry.EARLY
	if !_parry_timer.is_stopped():
		return Parry.IN_WINDOW
	return Parry.LATE

# The player's sword connected. Mid-attack, timing against the twinkle decides it: in
# the window the enemy is parried; early, it blocks and staggers the player but keeps
# attacking; late, the swing does nothing and the enemy's strike lands. Otherwise it's
# an ordinary hit.
#
# An unparryable attack (red twinkle) can't be met head on: before it strikes, a sword hit
# from the front is blocked and staggers the player, whatever the timing. One from behind
# (the sword travelling the way the enemy faces, after rolling through it) lands.
#
# Either way, a swing the player started before the enemy began its attack isn't a clash:
# the player got in first, so it's an ordinary hit (which cuts the attack short).
#
# A swing that parries one enemy passes through any other it catches that would have
# blocked it (see _block_player_swing): no block, chip or stagger for the player.
func _on_player_sword(from_direction: String) -> void:
	if _unparryable && _animation_is(_attack_action()) && animator.frame <= attack_frame \
			&& !_swung_first():
		if from_direction == direction:
			take_damage(from_direction, player.sword_damage())
		else:
			_block_player_swing.call_deferred(from_direction, player.swing_started_frame)
		return
	match _parry_timing():
		Parry.NONE:
			take_damage(from_direction, player.sword_damage())
		Parry.IN_WINDOW:
			player.mark_swing_parried()
			_parry_feedback()
			if _parried_follow_up():
				_parry_progress = 0.5 # Half way: the follow-up still has to be parried
			else:
				_parry_progress = 1.0
				stagger(from_direction)
		Parry.EARLY:
			_block_player_swing.call_deferred(from_direction, player.swing_started_frame)
		Parry.LATE:
			pass

# Blocks the player's swing (begun on physics frame `swing_frame`) and staggers them, unless
# that swing parried another enemy: then it just passes through this one, no block, chip or
# stagger. Called deferred, at the end of the physics frame, so a parry the same swing lands
# on another enemy in the same frame counts whichever contact the engine reported first.
func _block_player_swing(from_direction: String, swing_frame: int) -> void:
	if player.swing_parried(swing_frame):
		return
	_parry_feedback(true)
	player.stagger()
	_chip(Direction.to_vector(from_direction))

# `blocked`: the player swung too early and is the one staggered, so the clank sounds bad.
func _parry_feedback(blocked := false) -> void:
	var at := (global_position + player.global_position) / 2
	Juice.burst(room, at, PARRY_SPARK, 14, 110.0, Vector2.ZERO, 2.0, 0.3)
	Juice.clank(blocked)
	Juice.hitstop(PARRY_HITSTOP)
	Juice.shake(Juice.SHAKE_MEDIUM)

# The animation whose windup can be parried.
func _attack_action() -> String:
	return "slash"

# Call as an attack starts.
func _mark_attack_start() -> void:
	_attack_started_frame = Engine.get_physics_frames()

# The player's current swing began before the attack under way started, or on the same
# frame (before its first frame was even drawn). Counted in physics frames, which hit-stop
# and frame rate can't blur.
func _swung_first() -> bool:
	return _attack_started_frame >= 0 && player.swing_started_frame <= _attack_started_frame

# Parried in the window. Return true to carry on attacking (having started a follow-up)
# instead of being staggered.
func _parried_follow_up() -> bool:
	return false

# Starts the attack animation over from its first frame, as a fresh attack whose windup
# hold lasts `hold` seconds.
func _restart_attack(hold: float) -> void:
	_end_windup_hold()
	_windup_held = false
	_twinkled_at = -1
	_next_hold = hold
	_mark_attack_start()
	_play(_attack_action())
	animator.frame = 0

func is_stunned() -> bool:
	return !_stun_timer.is_stopped()

func is_vulnerable() -> bool:
	return !_vulnerable_timer.is_stopped()

# Parried: the attack is cancelled, the enemy is knocked back the way the player's sword
# travels and stunned for a moment, and its next hit taken (within
# Tuning.stagger_vulnerable_time) is multiplied.
func stagger(from_direction: String) -> void:
	_end_windup_hold()
	knockback = Direction.to_vector(from_direction) * knockback_speed * Tuning.parried_knockback
	_stun_timer.start(Tuning.parried_stun_time)
	_set_vulnerable(true)
	_show_dizzy(true)
	_play("idle")
	_on_staggered()
	player.start_finisher(self) # Swings skip their cooldown while this enemy is stunned

func _set_vulnerable(on: bool) -> void:
	if on:
		_vulnerable_timer.start(Tuning.stagger_vulnerable_time)
	else:
		_vulnerable_timer.stop()

func _show_dizzy(on: bool) -> void:
	if is_instance_valid(_dizzy):
		_dizzy.queue_free()
	if on:
		_dizzy = Juice.dizzy(self, dizzy_offset)

# Call every frame. Freezes the attack animation on its last windup frame, once per
# attack: a random windup hold, then the twinkle, then Tuning.parry_window, then the strike.
# The attack cooldown is paused too, so the hold adds to the time between attacks
# instead of eating into it.
func _update_windup() -> void:
	if !_animation_is(_attack_action()):
		if !is_stunned():
			_parry_progress = 0.0 # The attack ended without the parries to stagger it
		_windup_held = false
		_twinkled_at = -1
		_unparryable = false
		_attack_started_frame = -1
		return
	if _attack_started_frame < 0: # Subclasses that don't mark their attacks
		_mark_attack_start()
	if _windup_held || windup_hold_max <= 0 || animator.frame != maxi(attack_frame - 1, 0):
		return
	_windup_held = true
	animator.pause()
	attack_cooldown.paused = true
	var hold := _next_hold if _next_hold >= 0 else randf_range(windup_hold_min, maxf(windup_hold_min, windup_hold_max))
	_next_hold = -1.0
	if hold > 0:
		_twinkle_timer.start(hold)
	else:
		_twinkle()

# The "about to strike" glint, out in front of the enemy's face. Opens the parry window,
# or for an unparryable attack the longer Tuning.unparryable_window to roll behind in.
func _twinkle() -> void:
	_twinkled_at = Time.get_ticks_msec()
	_parry_timer.start(Tuning.unparryable_window if _unparryable else Tuning.parry_window)
	var forward := Direction.to_vector(direction) * twinkle_offset.x
	Juice.twinkle(self, forward + Vector2(0, twinkle_offset.y),
		UNPARRYABLE_TWINKLE_COLOR if _unparryable else TWINKLE_COLOR)

# Carries the attack through, unless something (like a hit) already replaced it.
func _end_windup_hold() -> void:
	_twinkle_timer.stop() # An interrupted attack gives no warning
	_parry_timer.stop()
	attack_cooldown.paused = false
	if !animator.is_playing():
		animator.play()

# Slides off any knockback from the last hit.
func _apply_knockback(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	velocity = knockback
	move_and_slide()
	knockback = velocity
	_keep_off_side_walls()

# Holds the enemy side_wall_margin away from the room's left and right walls.
func _keep_off_side_walls() -> void:
	if side_wall_margin <= 0:
		return
	# position is room-local, since enemies are direct children of their room.
	var floor_rect := room.floor_rect
	position.x = clampf(position.x, floor_rect.position.x + side_wall_margin,
		floor_rect.end.x - side_wall_margin)

func _on_invincibility_cooldown_timeout() -> void:
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_hurtbox_area_shape_entered(_area_id: RID, area: Area2D, _area_shape: int, _self_shape: int) -> void:
	if area.get_name() == "Hitbox":
		_on_player_sword(area.get_parent().get_parent().direction)
	elif area.get_name() == "ArrowHitbox":
		var arrow: Projectile = area.get_parent()
		take_damage(arrow.direction, arrow.damage)
	elif area.get_name() == "ProjectileHitbox": # A shot the player deflected
		var shot: Projectile = area.get_parent()
		if !shot.hostile_to_player:
			take_damage(shot.direction, shot.damage)
