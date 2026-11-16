class_name Enemy
extends CharacterBody2D

# Shared code for everything the player can fight. Subclasses decide how to move and
# attack; this handles facing, knockback, taking hits and dying.
#
# An enemy lives directly under its Room and only acts while the player is in that room.
# Animations are named "<action>_<direction>", e.g. "slash_left".

signal died(enemy: Enemy)

const KNOCKBACK_FRICTION := 200 # Pixels/sec lost per second
const CRIT_ROLL_MAX := 30 # A hit crits when randi_range(0, CRIT_ROLL_MAX) < damage upgrade level
const CLOSE_RANGE := 25 # Pixels on either axis
const SWORD_DAMAGE := 1.0 # Health a sword hit takes; arrows carry their own damage

@export var speed: float
@export var knockback_speed: float
@export var damage: float # Read by the player when this enemy's Hitbox touches it
@export var health: float
@export var attack_frame: int # Attack animation frame the hit or shot happens on
@export var attack_end_frame: int # Attack animation frame that returns to idle
@export var attack_cooldown_length: float
# Parrying. The attack animation freezes on its last windup frame (the one before
# attack_frame) for a random windup hold, rolled within this range each attack. Then a
# twinkle shows and the enemy holds PARRY_WINDOW longer before striking. A sword hit in
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
var _twinkled_at := -1 # Ticks (ms) the current attack's twinkle showed; -1 before it does
var _twinkle_timer: Timer # Counts down the random part of the windup hold
var _parry_timer: Timer # Running while the parry window is open
var _stun_timer: Timer # Running while stunned from being parried
var _vulnerable_timer: Timer # Running while the next hit taken is multiplied
var _dizzy: Node2D # Stars shown while stunned

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
const PARRY_WINDOW := 0.25 # Seconds from the twinkle to the strike; a sword hit in it parries
const PARRIED_STUN_TIME := 1.0 # Seconds a parried enemy stands helpless
const PARRIED_KNOCKBACK := 0.5 # Times knockback_speed for being parried
const PARRY_SPARK := Color(1, 0.95, 0.7)
const PARRY_HITSTOP := 0.1
const FEET_OFFSET := Vector2(0, 8) # From the origin down to where the enemy stands

func _ready() -> void:
	critical_chance = SaveData.damage_level
	Juice.add_flash(animator)
	_twinkle_timer = _add_timer(_twinkle)
	_parry_timer = _add_timer(_end_windup_hold)
	_stun_timer = _add_timer(_show_dizzy.bind(false))
	_vulnerable_timer = _add_timer(_set_vulnerable.bind(false))

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
	knockback = Direction.to_vector(from_direction) * knockback_speed
	var hit_dir := Direction.to_vector(from_direction)
	if !is_vulnerable() && _blocks_hit():
		# Sparks fly back towards the attacker.
		Juice.burst(room, global_position - hit_dir * 6, Color(1, 0.9, 0.5), 6, 70.0, -hit_dir, 1.5, 0.25)
		Juice.hitstop(HITSTOP_BLOCK)
		Juice.shake(Juice.SHAKE_LIGHT)
		return
	
	# Interrupts an attack. Faces the direction the hit travels in, not the attacker.
	if _animation_is("slash"):
		_end_windup_hold()
		_play("idle", from_direction)
	
	hurtbox.set_deferred("disabled", true) # Called from a collision callback
	invincibility_cooldown.start(invincibility_time)
	animator.modulate.a = 0.5
	
	if is_vulnerable():
		amount *= Constants.STAGGER_DAMAGE_MULTIPLIER
		_set_vulnerable(false)
	var critical := _roll_critical()
	_lose_health(amount, critical)
	_hit_feedback(hit_dir, critical, health <= 0)
	if health <= 0:
		die()
	_after_hit()

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
	if randf() < Constants.ARROW_DROP_CHANCE:
		Juice.drop_arrows(room, global_position, randi_range(1, Constants.ARROW_DROP_MAX))
	died.emit(self)
	queue_free()

func is_player_in_room() -> bool:
	return player.current_room == room.room_id

# --- Overridable hooks ---

# True when a hit should be shrugged off (knockback still applies).
func _blocks_hit() -> bool:
	return false

func _roll_critical() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(0, CRIT_ROLL_MAX) < critical_chance

func _lose_health(amount: float, critical: bool) -> void:
	if critical:
		health = 0
	else:
		health -= amount

func _after_hit() -> void:
	pass

# Just parried (already idle and stunned); show it.
func _on_staggered() -> void:
	pass

# Coins are coin_reward times "floor.looting": floor 1 with no looting is x1.0, floor 1 with
# looting 1 is x1.1, floor 2 with looting 3 is x2.3. Looting tops out at 9, one decimal digit.
func _coin_multiplier() -> float:
	return Game.overworld.floor_number + SaveData.looting_level / 10.0

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
	if _twinkled_at < 0 || player.swing_started_at < _twinkled_at:
		return Parry.EARLY
	if !_parry_timer.is_stopped():
		return Parry.IN_WINDOW
	return Parry.LATE

# The player's sword connected. Mid-attack, timing against the twinkle decides it: in
# the window the enemy is parried; early, it blocks and staggers the player but keeps
# attacking; late, the swing does nothing and the enemy's strike lands. Otherwise it's
# an ordinary hit.
func _on_player_sword(from_direction: String) -> void:
	match _parry_timing():
		Parry.NONE:
			take_damage(from_direction, SWORD_DAMAGE)
		Parry.IN_WINDOW:
			_parry_feedback()
			stagger(from_direction)
		Parry.EARLY:
			_parry_feedback()
			player.stagger()
		Parry.LATE:
			pass

func _parry_feedback() -> void:
	var at := (global_position + player.global_position) / 2
	Juice.burst(room, at, PARRY_SPARK, 14, 110.0, Vector2.ZERO, 2.0, 0.3)
	Juice.clank()
	Juice.hitstop(PARRY_HITSTOP)
	Juice.shake(Juice.SHAKE_MEDIUM)

# The animation whose windup can be parried.
func _attack_action() -> String:
	return "slash"

func is_stunned() -> bool:
	return !_stun_timer.is_stopped()

func is_vulnerable() -> bool:
	return !_vulnerable_timer.is_stopped()

# Parried: the attack is cancelled, the enemy is knocked back the way the player's sword
# travels and stunned for a moment, and its next hit taken (within
# STAGGER_VULNERABLE_TIME) is multiplied.
func stagger(from_direction: String) -> void:
	_end_windup_hold()
	knockback = Direction.to_vector(from_direction) * knockback_speed * PARRIED_KNOCKBACK
	_stun_timer.start(PARRIED_STUN_TIME)
	_set_vulnerable(true)
	_show_dizzy(true)
	_play("idle")
	_on_staggered()

func _set_vulnerable(on: bool) -> void:
	if on:
		_vulnerable_timer.start(Constants.STAGGER_VULNERABLE_TIME)
	else:
		_vulnerable_timer.stop()

func _show_dizzy(on: bool) -> void:
	if is_instance_valid(_dizzy):
		_dizzy.queue_free()
	if on:
		_dizzy = Juice.dizzy(self, dizzy_offset)

# Call every frame. Freezes the attack animation on its last windup frame, once per
# attack: a random windup hold, then the twinkle, then PARRY_WINDOW, then the strike.
# The attack cooldown is paused too, so the hold adds to the time between attacks
# instead of eating into it.
func _update_windup() -> void:
	if !_animation_is(_attack_action()):
		_windup_held = false
		_twinkled_at = -1
		return
	if _windup_held || windup_hold_max <= 0 || animator.frame != maxi(attack_frame - 1, 0):
		return
	_windup_held = true
	animator.pause()
	attack_cooldown.paused = true
	var hold := randf_range(windup_hold_min, maxf(windup_hold_min, windup_hold_max))
	if hold > 0:
		_twinkle_timer.start(hold)
	else:
		_twinkle()

# The "about to strike" glint, out in front of the enemy's face. Opens the parry window.
func _twinkle() -> void:
	_twinkled_at = Time.get_ticks_msec()
	_parry_timer.start(PARRY_WINDOW)
	var forward := Direction.to_vector(direction) * twinkle_offset.x
	Juice.twinkle(self, forward + Vector2(0, twinkle_offset.y))

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
