class_name Wyrm
extends Enemy

# Dragons: the wyrm and the wyvern (Wyvern.tscn, the same script with bigger numbers). They
# fly, so pits and special tiles leave them alone (see Enemy.flies), though stalagmites and
# walls still stop them.
#
# Noticing the player works as it does for goblins and knights (MeleeEnemy): until then it
# hovers where it started, facing starting_direction (or turning to the door the player came
# in by, for AUTO_FACING). It notices a player within detection_radius anywhere but behind
# it, or anything hitting it, and alerts the rest of the room within Tuning.alert_radius;
# then it fights until the player leaves the room. Both are set per dragon in the room
# creator.
#
# Fighting, it circles at Tuning.wyrm_orbit_radius, now and then turning round to circle the
# other way. It keeps its distance: a player who gets inside Tuning.wyrm_keep_away of the
# circle sends it backing straight off at Tuning.wyrm_retreat_speed times its speed. A hit
# that lands, or coming round from a stun, sends it backing off for Tuning.wyrm_hit_back_off
# before it can attack again. Only its attacks hurt: there's no damage for touching it. Every
# so often (Tuning.wyrm_attack_cooldown_min/max) it stops to attack, one of two ways:
#
# Fireball (the "shoot" animation): it rears back and holds its breath, rooted and glowing
# faster and faster, for Tuning.wyrm_fireball_charge_time, long enough for the player to
# close in; a hit that lands then cancels the fireball. A glint at its mouth comes a parry
# window before it breathes. A wyrm's fireball flies straight; a wyvern's homes like a
# wizard's (homing_fireball). Either can be hit back with the sword, and then homes on the
# dragon that breathed it; dragons don't bat it back again the way wizards do. Hit back
# within Tuning.wyrm_fireball_counter_window of coming out (a swing on the glint) it's a
# counter, and stuns the dragon like a parry when it lands. Breathing can't be parried.
#
# Charge (the "slash" animation, so the shared windup and parry code in Enemy times it): it
# coils (frame 0), then freezes in its lunge pose (frame 1) for the usual random windup hold,
# aims at the player and dashes straight at them at Tuning.wyrm_charge_speed. Half a parry
# window before it gets within Tuning.wyrm_clash_reach of them it glints and pulls up there,
# hanging in front of the player until the window closes; then it bites (frame 2, its
# Hitbox live for that frame only) and carries on through, harmless, for
# Tuning.wyrm_charge_overshoot. Parried in the
# window it's knocked back and stunned like any parried enemy; a swing that meets it before
# the glint is blocked and staggers the player. A wyvern's charges glint red
# Tuning.wyvern_heavy_charge_chance of the time: those can't be parried (Enemy._on_player_sword),
# so the player rolls through and hits it from behind, and it hangs in the air open for
# Tuning.wyvern_heavy_end_lag afterwards. Arrows don't stop a red charge either.
#
# A charge that slams into a wall or stalagmite dazes it exactly as a parry would (stars,
# Tuning.parried_stun_time, the next hit multiplied, the player's sword cooldown skipped).
#
# Dragons check in with the room's AttackCoordinator, so a goblin won't start a swing while
# a dragon is mid-charge (and the other way round), but never take melee turns. Dragons in
# the same room attack one at a time.

const Fireball := preload("res://src/projectiles/Fireball.tscn")
const CHARGE_SOUND := preload("res://assets/sfx/slash1.wav")
const CHARGE_PITCH := 0.6
const ORBIT_LEAD := 0.5 # Radians ahead round the circle it aims for
const BACK_OFF_LEAD := 0.3 # Share of ORBIT_LEAD while backing off: mostly straight away, sliding round a little
const ORBIT_WALL_MARGIN := 14.0 # Circle targets stay this far inside the floor
const ORBIT_ARRIVE := 2.0 # Pixels from a circle target that count as there
const ORBIT_STUCK_TIME := 0.4 # Seconds pressed against something before circling the other way
const SEPARATION := 30.0 # Pixels: closer than this to another enemy, it steers away from it
const FIRE_FLASH := Color(1, 0.6, 0.2) # Glow as it draws breath, warning of the fireball
const BREATH_FRAME := 1 # "shoot" frame it draws breath on
# Where fireballs leave its mouth, in its own (unscaled) units: this far out the way it
# faces, and MOUTH_HEIGHT above its origin.
const MOUTH_REACH := 16.0
const MOUTH_HEIGHT := -8.0
# Slamming into a wall mid-charge.
const WALL_HIT_SOUND := preload("res://assets/sfx/hit1.wav")
const WALL_HIT_PITCH := 0.7
const WALL_DUST := Color(0.75, 0.68, 0.55)
# Holding its breath before a fireball: a rising hiss and a glow that pulses faster as the
# breath comes.
const BREATH_SOUND := preload("res://assets/sfx/arrow_charge.wav")
const BREATH_PITCH := 0.6
const BREATH_PULSE_SLOW := 0.4 # Seconds between glows as it starts holding its breath...
const BREATH_PULSE_FAST := 0.1 # ...and just before it breathes

@export var homing_fireball := false # Wyverns: the fireball homes on the player
@export var has_heavy_charge := false # Wyverns: some charges glint red and can't be parried
@export var voice_pitch := 1.0 # Pitch of its sounds (wyverns deeper)
# Pixels: notices a player this close anywhere but behind it. Set per dragon in each room;
# the room creator draws it as a circle you can drag, as for goblins and knights.
@export_range(0, 400, 1) var detection_radius := MeleeEnemy.DEFAULT_DETECTION_RADIUS
# The way it faces when the room starts: a Direction, or MeleeEnemy.AUTO_FACING to turn to
# the player as they come into the room. Set per dragon with the room creator.
@export var starting_direction := Direction.RIGHT

# Seen the player (or been hit, or alerted by another enemy); fights until they leave the
# room. Named as in MeleeEnemy, whose _alert_pack sets it on anything that has it.
var noticed := false
var _was_noticed := false # noticed, last physics frame
var _orbit_dir := 1.0 # 1 circles clockwise, -1 anticlockwise
var _orbit_flip_in := 0.0 # Seconds until it may turn round
var _stuck_for := 0.0 # Seconds its circling has been pressed against something
var _moving := false # Flew this physics frame (picks "fly" over "idle")
var _charge_dir := Vector2.RIGHT # Fixed for a charge once it sets off
var _dashing := false # The charge under way has set off
var _dash_left := 0.0 # Pixels of the charge still to fly
var _recover: Timer # Running while it hovers after an attack, before circling again
var _recover_rooted := false # The recovery under way hangs still instead of backing off
var _charge_sound: AudioStreamPlayer
var _wall_sound: AudioStreamPlayer
var _breath_sound: AudioStreamPlayer
var _breath_timer: Timer # Running while it holds its breath before a fireball
var _breath_pulse_in := 0.0 # Seconds to the next warning glow while holding its breath
var _breath_glinted := false # The glint before this breath has shown
var _fireball: Projectile # Its last fireball, while it's still about
var _fireball_out_at := -1 # Ticks (ms) _fireball came out
var _fireball_countered := false # The player hit _fireball back within the counter window

@onready var _hitbox_pivot: Node2D = $HitboxPivot
@onready var _hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D

func _ready() -> void:
	super()
	_recover = _add_timer()
	_charge_sound = _add_sound(CHARGE_SOUND)
	_wall_sound = _add_sound(WALL_HIT_SOUND)
	_breath_sound = _add_sound(BREATH_SOUND)
	_breath_timer = _add_timer(_release_breath)
	_stun_timer.timeout.connect(_back_off) # Parried or dazed: once it comes round, it backs off
	if starting_direction == MeleeEnemy.AUTO_FACING:
		direction = Direction.RIGHT # Until the player comes in
		Game.room_entered.connect(_on_room_entered)
	else:
		direction = starting_direction
	_orbit_dir = [-1.0, 1.0].pick_random()
	_roll_cooldown()
	_play("idle")

func _add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"SFX"
	sound.stream = stream
	add_child(sound)
	return sound

func flies() -> bool:
	return true

# AUTO_FACING: the player has just come into this room. Unless it's already noticed them,
# it turns to face them, and so the way they came in.
func _on_room_entered(id: int) -> void:
	if id != room.room_id || noticed:
		return
	_face_player()
	_play("idle")

# --- Noticing the player (as MeleeEnemy) ---

# Within detection_radius, in front or to the side.
func _sees_player_nearby() -> bool:
	var offset := _to_player()
	return offset.length() <= detection_radius && Direction.to_vector(direction).dot(offset) >= 0

# Noticed the player: so does everyone else in the room within Tuning.alert_radius.
func _alert_pack() -> void:
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self && "noticed" in other && other.room == room \
				&& other.position.distance_to(position) <= Tuning.alert_radius:
			other.noticed = true

# Any hit gives the player away. One that lands (and doesn't stun it) cuts short a breath
# being held and sends it backing off before it attacks again.
func take_damage(from_direction: String, amount: float) -> void:
	if is_player_in_room():
		noticed = true
	var before := health
	super(from_direction, amount)
	if health >= before || health <= 0:
		return
	if _breath_held():
		_end_attack(0.0)
	if !_animation_is("slash") && !_animation_is("shoot") && !is_stunned():
		_back_off()

# Flies off for Tuning.wyrm_hit_back_off before it can attack again (after being hit, or
# coming round from a stun). Hanging open after a red charge, it stays put until that's
# over, and only then backs off before attacking.
func _back_off() -> void:
	if _recover_rooted && !_recover.is_stopped():
		attack_cooldown.start(maxf(attack_cooldown.time_left, _recover.time_left + Tuning.wyrm_hit_back_off))
		return
	_recover_rooted = false
	_recover.start(maxf(_recover.time_left, Tuning.wyrm_hit_back_off))
	attack_cooldown.start(maxf(attack_cooldown.time_left, Tuning.wyrm_hit_back_off))

func _process(_delta: float) -> void:
	if player.in_transition:
		_play("idle")
		return
	_update_windup()
	if !_animation_is("slash"): # Parried, interrupted or finished
		_hitbox.disabled = true
		_dashing = false
	if !_animation_is("shoot") && _breath_sound.playing: # A breath cut short
		_breath_sound.stop()

func _physics_process(delta: float) -> void:
	_moving = false
	if player.in_transition:
		return
	_watch_fireball()
	if !room.player_active || !is_player_in_room():
		noticed = false
		_was_noticed = false
		return
	if !noticed && _sees_player_nearby():
		noticed = true
	if noticed && !_was_noticed:
		_alert_pack()
	_was_noticed = noticed
	if !noticed: # Hovers where it started until it sees the player
		_apply_knockback(delta)
		return
	if is_stunned(): # Parried, or slammed into a wall
		_apply_knockback(delta)
		return
	var coordinator := AttackCoordinator.for_room(room)
	coordinator.check_in(self)
	if _animation_is("slash"):
		_charge(delta)
	elif _animation_is("shoot"):
		if _breath_held():
			_pulse_breath(delta)
		elif _animation_done():
			_end_attack(0.0)
	elif !_recover.is_stopped():
		if !_recover_rooted: # Backs off after an ordinary charge; hangs open after a red one
			_circle(delta)
			_play("fly" if _moving else "idle")
	else:
		_circle(delta)
		if _can_attack(coordinator):
			_start_attack()
		else:
			_play("fly" if _moving else "idle")
	_apply_knockback(delta)

func _on_reset() -> void:
	noticed = false
	_was_noticed = false
	_dashing = false
	_dash_left = 0.0
	_stuck_for = 0.0
	_recover.stop()
	_recover_rooted = false
	_breath_timer.stop()
	_breath_sound.stop()
	_hitbox.disabled = true
	_roll_cooldown()

# --- Circling ---

func _circle(delta: float) -> void:
	_orbit_flip_in -= delta
	if _orbit_flip_in <= 0:
		if randf() < 0.5:
			_orbit_dir = -_orbit_dir
		_orbit_flip_in = randf_range(Tuning.wyrm_orbit_flip_min,
			maxf(Tuning.wyrm_orbit_flip_min, Tuning.wyrm_orbit_flip_max))
	_face_player()
	var centre := room.to_local(player.global_position)
	var offset := position - centre
	if offset.length() < 1.0:
		offset = Vector2.RIGHT
	# A player inside its circle sends it backing straight off, quicker than it circles, so it
	# keeps its distance; it only comes close to attack.
	var backing_off := offset.length() < Tuning.wyrm_orbit_radius * Tuning.wyrm_keep_away
	var lead := ORBIT_LEAD * (BACK_OFF_LEAD if backing_off else 1.0)
	var target := centre + Vector2.from_angle(offset.angle() + _orbit_dir * lead) * Tuning.wyrm_orbit_radius
	target = room.clamp_to_floor(target + _separation(), ORBIT_WALL_MARGIN)
	var to_target := target - position
	if to_target.length() <= ORBIT_ARRIVE:
		return
	var fly_speed := speed * (Tuning.wyrm_retreat_speed if backing_off else 1.0)
	var motion := to_target.normalized() * minf(fly_speed * delta, to_target.length())
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		_stuck_for += delta
		if _stuck_for >= ORBIT_STUCK_TIME: # Pinned on a rock or wall: go round the other way
			_orbit_dir = -_orbit_dir
			_stuck_for = 0.0
	else:
		_stuck_for = 0.0
	_moving = true

# A nudge away from any other enemy too close, so dragons don't stack on the circle.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in room.get_children():
		var other := node as Enemy
		if other == null || other == self:
			continue
		var away := position - other.position
		if away.length() < SEPARATION:
			push += away.normalized() * (SEPARATION - away.length()) if away != Vector2.ZERO else Vector2.RIGHT
	return push

# --- Attacks ---

func _can_attack(coordinator: AttackCoordinator) -> bool:
	return attack_cooldown.is_stopped() && !coordinator.other_is_swinging(self) \
		&& !coordinator.rush_active() && !_other_dragon_attacking()

func _start_attack() -> void:
	if randf() < Tuning.wyrm_charge_chance:
		_start_charge(has_heavy_charge && randf() < Tuning.wyvern_heavy_charge_chance)
	else:
		_start_fireball()

# Another dragon in the room is breathing fire or charging.
func _other_dragon_attacking() -> bool:
	for node in room.get_children():
		var other := node as Wyrm
		if other != null && other != self && !other.is_queued_for_deletion() \
				&& (other._animation_is("shoot") || other._animation_is("slash")):
			return true
	return false

func _roll_cooldown() -> void:
	attack_cooldown.start(randf_range(Tuning.wyrm_attack_cooldown_min,
		maxf(Tuning.wyrm_attack_cooldown_min, Tuning.wyrm_attack_cooldown_max))
		* Tuning.enemy_attack_cooldown_multiplier)

# The attack is over. For `lag` seconds it doesn't attack: it backs off, or with `rooted`
# hangs where it is, open to hits. Then it circles again.
func _end_attack(lag: float, rooted := false) -> void:
	_dashing = false
	_dash_left = 0.0
	_breath_timer.stop()
	_hitbox.disabled = true
	_play("idle")
	_recover_rooted = rooted
	if lag > 0:
		_recover.start(lag)
	_roll_cooldown()

# The attack animation has played to its last frame.
func _animation_done() -> bool:
	return animator.frame == attack_end_frame && !animator.is_playing()

# --- Fireball ---

func _start_fireball() -> void:
	_face_player()
	_play("shoot")
	animator.frame = 0

# Reaching the breath frame, it freezes there, rooted and glowing, for
# Tuning.wyrm_fireball_charge_time: time for the player to close in and hit it, which cancels
# the fireball (see take_damage).
func _hold_breath() -> void:
	if Tuning.wyrm_fireball_charge_time <= 0:
		return
	animator.pause()
	_breath_timer.start(Tuning.wyrm_fireball_charge_time)
	_breath_pulse_in = 0.0
	_breath_glinted = false
	Juice.play(_breath_sound, 0.05, BREATH_PITCH * voice_pitch)

func _breath_held() -> bool:
	return _animation_is("shoot") && !_breath_timer.is_stopped()

# The warning glow, quickening as the breath comes, and a parry window before it the glint
# at its mouth that a counter is timed on.
func _pulse_breath(delta: float) -> void:
	if !_breath_glinted && _breath_timer.time_left <= Tuning.parry_window:
		_breath_glinted = true
		Juice.twinkle(self, _mouth_offset() / scale)
	_breath_pulse_in -= delta
	if _breath_pulse_in > 0:
		return
	var left := _breath_timer.time_left / maxf(Tuning.wyrm_fireball_charge_time, 0.001)
	_breath_pulse_in = lerpf(BREATH_PULSE_FAST, BREATH_PULSE_SLOW, left)
	Juice.flash(animator, _breath_pulse_in * 0.6, FIRE_FLASH)

func _release_breath() -> void:
	_breath_sound.stop()
	if _animation_is("shoot"):
		animator.play() # On to the frame that breathes the fireball

# From its origin to its mouth, where fireballs come out, scaled.
func _mouth_offset() -> Vector2:
	return (Direction.to_vector(direction) * MOUTH_REACH + Vector2(0, MOUTH_HEIGHT)) * scale

# Notes whether the player has hit its fireball back, and if so whether in time to count as a
# counter. Called every physics frame; a deflect happens at most a frame before it's seen.
func _watch_fireball() -> void:
	if !is_instance_valid(_fireball):
		_fireball = null
		return
	if _fireball.deflections == 1 && !_fireball.hostile_to_player && !_fireball_countered \
			&& Time.get_ticks_msec() - _fireball_out_at <= Tuning.wyrm_fireball_counter_window * 1000.0:
		_fireball_countered = true

# A countered fireball (see _watch_fireball) landing on it stuns it like a parry, on top of
# the damage.
func _on_hurtbox_area_shape_entered(area_id: RID, area: Area2D, area_shape: int, self_shape: int) -> void:
	var shot := area.get_parent() as Projectile
	var countered := area.get_name() == "ProjectileHitbox" && shot != null && shot == _fireball \
		&& _fireball_countered && !shot.hostile_to_player
	super(area_id, area, area_shape, self_shape)
	if countered && health > 0 && !is_stunned():
		_fireball_countered = false
		_parry_feedback()
		stagger(shot.direction)

func breathe_fire() -> void:
	if !is_player_in_room():
		return
	Juice.play($Attack, 0.08, voice_pitch)
	var fireball: Projectile = Fireball.instantiate()
	room.add_child(fireball)
	fireball.position = room.clamp_to_floor(position + _mouth_offset(), Projectile.SPAWN_MARGIN)
	_fireball = fireball
	_fireball_out_at = Time.get_ticks_msec()
	_fireball_countered = false
	fireball.direction = direction
	fireball.damage = damage
	fireball.speed = Tuning.wyrm_fireball_speed
	fireball.shooter = self # Hit back, it homes on this dragon
	fireball.launch_at(player)
	if !homing_fireball:
		fireball.homing_target = null # Keeps the heading it was launched on

# --- Charge (see the top of the file) ---

func _start_charge(heavy: bool) -> void:
	_aim_charge()
	_restart_attack(-1.0) # Fresh windup with a random hold
	_unparryable = heavy
	_dashing = false
	_dash_left = 0.0

func _aim_charge() -> void:
	var to_player := _to_player()
	_charge_dir = to_player.normalized() if to_player != Vector2.ZERO else Direction.to_vector(direction)
	_face_along(_charge_dir)
	_hitbox_pivot.rotation = _charge_dir.angle()

# The windup hold ends by setting off on the charge instead of glinting: the glint comes
# from _charge as it nears the player.
func _twinkle() -> void:
	if _animation_is("slash") && !_dashing:
		_begin_dash()
	else:
		super()

func _begin_dash() -> void:
	_aim_charge() # Re-aimed now, so the hold isn't a free head start to dodge
	_dashing = true
	_dash_left = minf(_to_player().length() + Tuning.wyrm_charge_overshoot, Tuning.wyrm_charge_max_distance)
	Juice.play(_charge_sound, 0.08, CHARGE_PITCH * voice_pitch)

func _charge(delta: float) -> void:
	if _dashing && _dash_left > 0:
		var step := minf(Tuning.wyrm_charge_speed * delta, _dash_left)
		if animator.frame < attack_frame: # Before the bite it pulls up at the player
			step = minf(step, maxf(_ahead_of_strike(), 0.0))
		var collision := move_and_collide(_charge_dir * step)
		_dash_left -= step
		# The side walls hold it back by margin rather than by collision (see
		# Enemy._keep_off_side_walls), so being pushed back off one counts as hitting it too.
		var before_clamp := position.x
		_keep_off_side_walls()
		if collision != null || !is_equal_approx(position.x, before_clamp):
			_slam_into_wall()
			return
	if _dashing && _twinkled_at < 0 && _due_to_glint():
		super._twinkle()
	if _animation_done() && _dash_left <= 0:
		if _unparryable:
			_end_attack(Tuning.wyvern_heavy_end_lag, true)
		else:
			_end_attack(Tuning.wyrm_charge_recovery)

# Flew into a wall or rock mid-charge: dazed just as if parried, bounced back off it.
func _slam_into_wall() -> void:
	var dust_at := global_position + _charge_dir * 10.0 * scale.x
	Juice.burst(room, dust_at, WALL_DUST, 14, 70.0, -_charge_dir, 2.0, 0.4)
	Juice.play(_wall_sound, 0.08, WALL_HIT_PITCH * voice_pitch)
	Juice.hitstop(PARRY_HITSTOP)
	Juice.shake(Juice.SHAKE_MEDIUM)
	stagger(_nearest_direction(-_charge_dir))

# Pixels along the charge before it's within Tuning.wyrm_clash_reach of the player.
func _ahead_of_strike() -> float:
	return _to_player().dot(_charge_dir) - Tuning.wyrm_clash_reach

# Glints half a window before reaching the player (so it hangs there for the other half),
# or before running out of charge.
func _due_to_glint() -> bool:
	var window := Tuning.unparryable_window if _unparryable else Tuning.parry_window
	var lead := Tuning.wyrm_charge_speed * window / 2.0
	return _ahead_of_strike() <= lead || _dash_left <= lead

# Partway through a charge, up to the bite. Other enemies hold off their own windups
# meanwhile (AttackCoordinator.other_is_swinging).
func is_swinging() -> bool:
	return _animation_is("slash") && animator.frame <= attack_frame

# Dragons never take a melee turn from the AttackCoordinator; they attack on their own clock.
func can_take_turn() -> bool:
	return false

# An arrow cuts an ordinary charge short; a red one ploughs on.
func _hit_interrupts_attack() -> bool:
	return !_unparryable

func _on_staggered() -> void:
	_dashing = false
	_dash_left = 0.0
	_roll_cooldown()

# --- Facing ---

func _face_player() -> void:
	_face_along(_to_player())

# Faces whichever of the four directions `heading` is nearest. Facing up draws it in front
# of the player, as for every enemy.
func _face_along(heading: Vector2) -> void:
	direction = _nearest_direction(heading)
	if direction == Direction.UP:
		z_index = 10
	elif direction == Direction.DOWN:
		z_index = 0

# Whichever of the four directions `heading` is nearest.
static func _nearest_direction(heading: Vector2) -> String:
	if absf(heading.x) >= absf(heading.y):
		return Direction.LEFT if heading.x < 0 else Direction.RIGHT
	return Direction.UP if heading.y < 0 else Direction.DOWN

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("shoot") && animator.frame == BREATH_FRAME:
		_hold_breath()
	elif _animation_is("shoot") && animator.frame == attack_frame:
		breathe_fire()
	elif _animation_is("slash") && animator.frame == attack_frame:
		Juice.play($Bite, 0.08, voice_pitch)
		_hitbox.disabled = false
	elif _animation_is("slash") && animator.frame > attack_frame:
		_hitbox.disabled = true # Only the bite itself hurts, not flying on through after it
