class_name Hobgoblin
extends MeleeEnemy

# A goblin that blows itself up on the player. It notices the player, alerts the room and
# roams as a goblin does (MeleeEnemy), but it doesn't wait for a turn or circle: it runs
# straight at the player. Within Tuning.hobgoblin_lunge_range it crouches (the slash
# windup, held and glinting white like any attack) and leaps at them at
# Tuning.hobgoblin_lunge_speed. Touching the player mid-leap sets it off: a blast of
# Tuning.hobgoblin_blast_radius that hurts the player and every enemy caught in it.
#
# A player rolling as it touches them is passed by, unhurt (rolling dodges it); the leap
# carries on past and it stands dazed for Tuning.hobgoblin_recover_time before coming again.
#
# A sword swing begun after the glint that meets it mid-leap parries it, like a dragon's
# charge: instead of being stunned it's flung the way the sword travels, at
# Tuning.hobgoblin_fling_speed, and goes off when it hits another enemy, a wall or a rock,
# or after Tuning.hobgoblin_fling_time. A flung hobgoblin's blast never hurts the player, so
# parrying one into a crowd is the way to use it. A spin that catches it flings it too.
#
# Any other hit is an ordinary one (it doesn't guard), and one that kills it just kills it:
# it only goes off by touching the player, after a parry, or when caught in another blast
# (one blast sets off any hobgoblin in it, which never hurts the player if the first
# didn't).

const BLAST_FIRE := Color(1, 0.55, 0.15)
const BLAST_SMOKE := Color(0.25, 0.22, 0.2, 0.8)
const BLAST_SPARKS := 30
const BLAST_PUFFS := 15
const BLAST_SPEED := 140.0
const BLAST_STAIN := 14.0 # Radius of the scorch it leaves
const BLAST_PITCH := 0.55 # Its attack sound, pitched right down, is the bang
const FLING_FLASH := Color(1, 0.4, 0.1) # Glows while flung, lit
const FLING_SPIN := 18.0 # Radians/sec it tumbles while flung

var _lunging := false
var _lunge_dir := Vector2.ZERO
var _lunge_left := 0.0 # Pixels of the leap still to go
var _lunge_started_at := -1 # Ticks (ms) the leap set off; swings begun after this parry it
var _flung := false
var _fling_dir := Vector2.ZERO
var _fling_left := 0.0 # Seconds before a flung one goes off anyway
var _exploded := false

func _physics_process(delta: float) -> void:
	_moving = false
	if player.in_transition:
		return
	if _flung:
		_fly(delta)
		return
	if !is_player_in_room():
		noticed = false
	if _lunging:
		_lunge_step(delta)
		return
	var engaged := is_detected()
	if engaged:
		noticed = true
	if noticed && !_was_noticed:
		_alert_pack()
	_was_noticed = noticed
	var coordinator := AttackCoordinator.for_room(room)
	if engaged:
		coordinator.check_in(self) # So nobody else starts a windup while it's leaping
	if !_animation_is("slash"):
		_update_facing()
		_point_pivots()
	if _is_reacting() || _animation_is("slash"):
		pass # Dazed, flinching, or crouched to leap
	elif engaged:
		_fight_alone(coordinator, delta)
	elif _can_roam():
		_roam(delta)
	_apply_knockback(delta)

# Runs at the player, and crouches to leap once close enough (and nobody else is mid-swing).
func _fight_alone(coordinator: AttackCoordinator, delta: float) -> void:
	if _to_player().length() <= Tuning.hobgoblin_lunge_range:
		if attack_cooldown.is_stopped() && !coordinator.other_is_swinging(self) \
				&& !coordinator.rush_active():
			_start_swing(_is_player_mostly_horizontal())
		return
	_walk_to(_player_position(), speed, delta, ARRIVE_DISTANCE)

# Never takes a melee turn or joins a group rush: it comes on its own clock.
func can_take_turn() -> bool:
	return false

# Crouched to leap, or mid-leap: others hold off their own windups.
func is_swinging() -> bool:
	return _lunging || (_animation_is("slash") && animator.frame <= attack_frame)

# The glint: it sets off at once, at the player.
func _twinkle() -> void:
	super()
	_start_lunge()

func _start_lunge() -> void:
	var to_player := _to_player()
	_lunging = true
	_lunge_started_at = Time.get_ticks_msec()
	_lunge_dir = to_player.normalized() if to_player.length() > 0.01 else Direction.to_vector(direction)
	_lunge_left = to_player.length() + Tuning.hobgoblin_lunge_overshoot
	Juice.play($Attack, 0.08, voice_pitch)

func _lunge_step(delta: float) -> void:
	if _touching_player():
		explode(true)
		return
	var step := minf(Tuning.hobgoblin_lunge_speed * delta, _lunge_left)
	var collision := move_and_collide(_lunge_dir * step)
	_lunge_left -= step
	if collision != null && collision.get_collider() == player && _touching_player():
		explode(true)
	elif collision != null || _lunge_left <= 0:
		_end_lunge()

# Close enough to set off, and the player isn't rolling past (rolling dodges it).
func _touching_player() -> bool:
	return player.rolling.time_left == 0 && _to_player().length() <= Tuning.hobgoblin_contact_reach

# Missed: it lands and stands dazed for a moment before coming again.
func _end_lunge() -> void:
	_lunging = false
	_end_windup_hold()
	_play("idle")
	attack_cooldown.start(Tuning.hobgoblin_recover_time)

# A leaping hobgoblin is parried by a swing begun after it set off (it can't be timed
# against a fixed window: it's coming at the player, like a dragon's charge). Before that,
# or outside a leap, the sword just hits it.
func _on_player_sword(from_direction: String) -> void:
	if _flung || _exploded:
		return
	if _lunging && player.swing_started_at >= _lunge_started_at:
		player.mark_swing_parried()
		_parry_feedback()
		stagger(from_direction)
		return
	take_damage(from_direction, player.sword_damage())

# It doesn't guard; see the top of the file.
func _can_guard(_from_direction: String) -> bool:
	return false

func _guards_spin(_from_direction: String) -> bool:
	return false

# A leap that's hit (an arrow) carries on.
func _hit_interrupts_attack() -> bool:
	return !_lunging

# Parried (or spun into): flung the way the hit travels, lit.
func stagger(from_direction: String, _stun_time := -1.0) -> void:
	_fling(Direction.to_vector(from_direction))

func _fling(dir: Vector2) -> void:
	_end_windup_hold()
	_lunging = false
	_flung = true
	_fling_dir = dir
	_fling_left = Tuning.hobgoblin_fling_time
	knockback = Vector2.ZERO
	invincibility_cooldown.stop()
	hurtbox.set_deferred("disabled", true) # Nothing more to hit; it's a bomb now
	_play("idle")
	Juice.flash(animator, Tuning.hobgoblin_fling_time, FLING_FLASH)

# Flies on until it hits something or its fuse runs out, then goes off, sparing the player.
func _fly(delta: float) -> void:
	_fling_left -= delta
	animator.rotation += FLING_SPIN * delta
	var collision := move_and_collide(_fling_dir * Tuning.hobgoblin_fling_speed * delta)
	if collision != null || _fling_left <= 0 || _enemy_in_reach():
		explode(false)

# Another enemy close enough to set it off (a flying dragon it can't collide with, say).
func _enemy_in_reach() -> bool:
	for node in room.get_children():
		var other := node as Enemy
		if other != null && other != self && !other.is_queued_for_deletion() \
				&& other.global_position.distance_to(global_position) <= Tuning.hobgoblin_contact_reach:
			return true
	return false

# Goes off: everything within Tuning.hobgoblin_blast_radius is caught, the player too if
# `hurts_player`. It dies in it.
func explode(hurts_player: bool) -> void:
	if _exploded:
		return
	_exploded = true
	_lunging = false
	var at := global_position
	Juice.burst(room, at, BLAST_FIRE, BLAST_SPARKS, BLAST_SPEED, Vector2.ZERO, 2.5, 0.45)
	Juice.burst(room, at, BLAST_SMOKE, BLAST_PUFFS, BLAST_SPEED / 2, Vector2.UP, 3.0, 0.7)
	Juice.splat(room, at + FEET_OFFSET, BLAST_SMOKE.darkened(0.3), BLAST_STAIN)
	Juice.play($Attack, 0.05, BLAST_PITCH * voice_pitch)
	Juice.shake(Juice.SHAKE_HEAVY)
	Juice.hitstop(HITSTOP_KILL)
	for node in room.get_children():
		var other := node as Enemy
		if other == null || other == self || other.is_queued_for_deletion() \
				|| other.global_position.distance_to(at) > Tuning.hobgoblin_blast_radius:
			continue
		if other is Hobgoblin:
			(other as Hobgoblin).caught_in_blast(hurts_player)
		else:
			other.hurt_by_blast(at, Tuning.hobgoblin_blast_enemy_damage)
	var to_player := player.global_position - at
	if hurts_player && to_player.length() <= Tuning.hobgoblin_blast_radius:
		player.take_damage(Tuning.hobgoblin_blast_damage, _nearest_direction(to_player), false)
	health = 0
	die()

# Another blast reached it: it goes off too, next frame, so a chain ripples outward.
func caught_in_blast(hurts_player: bool) -> void:
	if !_exploded:
		explode.call_deferred(hurts_player)

func hurt_by_blast(_from: Vector2, _amount: float) -> void:
	caught_in_blast(false)

static func _nearest_direction(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return Direction.LEFT if v.x < 0 else Direction.RIGHT
	return Direction.UP if v.y < 0 else Direction.DOWN

# No slash hitbox: only the blast hurts.
func _on_animated_sprite_2d_frame_changed() -> void:
	pass

func _on_reset() -> void:
	super()
	_lunging = false
	_flung = false
	_lunge_left = 0.0
	animator.rotation = 0.0
	hurtbox.disabled = false
