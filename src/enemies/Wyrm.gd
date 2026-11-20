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
# creator. Having noticed them, it first flies off (see _open_fight) for
# Tuning.wyrm_first_attack_delay before it can attack.
#
# Fighting, it circles at Tuning.wyrm_orbit_radius, now and then turning round to circle the
# other way. It keeps its distance: a player who gets inside Tuning.wyrm_keep_away of the
# circle sends it backing straight off at the player's walking speed. A hit
# that lands, or coming round from a stun, sends it backing off for Tuning.wyrm_hit_back_off
# before it can attack again. Only its attacks hurt: there's no damage for touching it. Every
# so often (Tuning.wyrm_attack_cooldown_min/max) it stops to attack, one of two ways:
#
# Fireball (the "shoot" animation): it rears back and holds its breath, rooted and glowing
# faster and faster, for Tuning.wyrm_fireball_charge_time, long enough for the player to
# close in. A glint at its mouth comes Tuning.wyrm_breath_parry_window before it breathes,
# and the sword is timed against it like any parry: a swing at it while it rears back or
# holds its breath, before the glint, is blocked and staggers the player; one on the glint
# parries it, choking off the fireball and stunning it. An arrow or spin that lands chokes
# the fireball off too. A wyrm's fireball flies straight; a wyvern's homes like a wizard's
# (homing_fireball). Either can be hit back with the sword, and then homes on the dragon
# that breathed it, which bats it back again the way wizards do (FireballReturner); one that
# gets through only damages it.
#
# Its stuns, from a parry or a wall, give the player no damage bonus on the next hit (see
# stagger).
#
# Charge (the "slash" animation, so the shared windup and parry code in Enemy times it): it
# coils (frame 0), then hangs still in its lunge pose (frame 1) for about a second
# (Tuning.wyrm_charge_hold_min/max). Then it glints, aims at the player and dashes straight
# at them at Tuning.wyrm_charge_speed without stopping, biting (frame 2, its Hitbox live for
# that frame only) the moment it gets within Tuning.wyrm_clash_reach of them, and carries on
# through, harmless, for Tuning.wyrm_charge_overshoot. A swing begun after the glint that
# meets it up to the bite parries it: knocked back and stunned like any parried enemy. One
# that meets it before the glint is blocked and staggers the player. A wyvern's charges
# glint red Tuning.wyvern_heavy_charge_chance of the time: those can't be parried (Enemy._on_player_sword),
# so the player rolls through and hits it from behind, and it hangs in the air open for
# Tuning.wyvern_heavy_end_lag afterwards. Arrows don't stop a red charge either.
#
# A charge that slams into a wall or stalagmite dazes it exactly as a parry would (stars,
# Tuning.parried_stun_time, the player's sword cooldown skipped).
#
# Dragons check in with the room's AttackCoordinator, so a goblin won't start a swing while
# a dragon is mid-charge (and the other way round), but never take melee turns. Dragons in
# the same room attack one at a time, the others waiting Tuning.wyrm_pack_attack_gap after
# each attack.

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
# Batting fireballs back (FireballReturner), in its own (unscaled) units: this far ahead of
# it, and this far either side of the fireball's path. Wider than its hurtbox, so a fast
# fireball can't skip past the point it's batted in one frame.
const RETURN_REACH := 36.0
const RETURN_WIDTH := 16.0
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
# A fireball parried on the glint bursts in its mouth: flame, smoke and a low boom.
const MOUTH_BLAST_SPARKS := 22
const MOUTH_BLAST_SPEED := 110.0
const MOUTH_BLAST_SMOKE := Color(0.35, 0.3, 0.3)
const MOUTH_BLAST_PITCH := 0.55

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
var _opening: Timer # Running while it flies off after first noticing the player
var _charge_sound: AudioStreamPlayer
var _wall_sound: AudioStreamPlayer
var _breath_sound: AudioStreamPlayer
var _breath_timer: Timer # Running while it holds its breath before a fireball
var _breath_pulse_in := 0.0 # Seconds to the next warning glow while holding its breath
var _breath_glinted := false # The glint before this breath has shown
var _breath_glint_at := -1 # Ticks (ms) that glint showed; -1 before it does
var _fireball: Projectile # Its last fireball, while it's still about
var _returner: FireballReturner # Bats back fireballs the player hits at it

@onready var _hitbox_pivot: Node2D = $HitboxPivot
@onready var _hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D

func _ready() -> void:
	super()
	_recover = _add_timer()
	_opening = _add_timer()
	_charge_sound = _add_sound(CHARGE_SOUND)
	_wall_sound = _add_sound(WALL_HIT_SOUND)
	_breath_sound = _add_sound(BREATH_SOUND)
	_breath_timer = _add_timer(_release_breath)
	_returner = FireballReturner.new(self, RETURN_REACH * scale.x, RETURN_WIDTH * scale.x, FIRE_FLASH)
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

# Any hit gives the player away. One that lands (and doesn't stun it) sends it backing off
# before it attacks again; landing while it charges a fireball (an arrow, a spin: the sword
# is dealt with in _on_player_sword) also chokes the fireball off.
func take_damage(from_direction: String, amount: float) -> void:
	if is_player_in_room():
		noticed = true
	var before := health
	super(from_direction, amount)
	if health >= before || health <= 0:
		return
	if _charging_fireball():
		_choke_breath()
	if !_animation_is("slash") && !_animation_is("shoot") && !is_stunned():
		_back_off()

# The sword meets it while it charges a fireball: timed like a parry against the glint at
# its mouth, which comes Tuning.wyrm_breath_parry_window before the fireball. Swung before
# the glint, the swing is blocked and the player staggered, as when swinging early at any
# attack; swung on the glint and connecting before the fireball comes out, it's parried and
# stunned, the fireball choked off (so none ever appears). A swing on the glint that only
# connects once the fireball is out is late and does nothing to the dragon, as a late swing
# does nothing to any attack. Otherwise as for any enemy.
func _on_player_sword(from_direction: String) -> void:
	var on_glint := _breath_glint_at >= 0 && player.swing_started_at >= _breath_glint_at
	if _charging_fireball():
		if on_glint:
			player.mark_swing_parried()
			_choke_breath()
			_parry_feedback()
			_explode_in_mouth()
			stagger(from_direction)
		else:
			_block_player_swing.call_deferred(from_direction, player.swing_started_frame)
	elif !(on_glint && _animation_is("shoot")): # Late: nothing
		super(from_direction)

# Parried on the glint: the fireball it was about to breathe bursts in its mouth instead.
func _explode_in_mouth() -> void:
	var at := global_position + _mouth_offset()
	Juice.burst(room, at, FIRE_FLASH, MOUTH_BLAST_SPARKS, MOUTH_BLAST_SPEED, Vector2.ZERO, 2.5, 0.45)
	Juice.burst(room, at, MOUTH_BLAST_SMOKE, MOUTH_BLAST_SPARKS / 2, MOUTH_BLAST_SPEED / 2, Vector2.UP, 3.0, 0.6)
	Juice.flash(animator, 0.2, FIRE_FLASH)
	Juice.play($Attack, 0.05, MOUTH_BLAST_PITCH * voice_pitch)
	Juice.shake(Juice.SHAKE_HEAVY)

# Stops a fireball before it comes out. Not _end_attack: this can run inside a collision
# callback, where the bite hitbox can't be switched (it's off anyway while breathing fire).
func _choke_breath() -> void:
	_breath_timer.stop()
	_play("idle")
	_roll_cooldown()

# Just noticed the player: it flies off out to Tuning.wyrm_first_back_off_radius times its
# circle and doesn't attack for Tuning.wyrm_first_attack_delay, so the fight opens with a
# moment to size it up rather than an attack straight away.
func _open_fight() -> void:
	var delay := Tuning.wyrm_first_attack_delay
	_opening.start(maxf(delay, 0.001))
	_recover_rooted = false
	_recover.start(maxf(_recover.time_left, maxf(delay, 0.001)))
	attack_cooldown.start(maxf(attack_cooldown.time_left, maxf(delay, 0.001)))

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
	if !room.player_active || !is_player_in_room():
		noticed = false
		_was_noticed = false
		return
	if !noticed && _sees_player_nearby():
		noticed = true
	if noticed && !_was_noticed:
		_alert_pack()
		_open_fight()
	_was_noticed = noticed
	if !noticed: # Hovers where it started until it sees the player
		_apply_knockback(delta)
		return
	if is_stunned(): # Parried, or slammed into a wall
		_apply_knockback(delta)
		return
	if _returner.try_return():
		_face_along(Direction.to_vector(direction)) # Draw order for the way it now faces
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
	_opening.stop()
	_returner.reset()
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
	# Just after noticing the player it keeps further off (see _open_fight).
	var opening := !_opening.is_stopped()
	var radius := Tuning.wyrm_orbit_radius * (Tuning.wyrm_first_back_off_radius if opening else 1.0)
	var backing_off := offset.length() < radius * (1.0 if opening else Tuning.wyrm_keep_away)
	var lead := ORBIT_LEAD * (BACK_OFF_LEAD if backing_off else 1.0)
	var target := centre + Vector2.from_angle(offset.angle() + _orbit_dir * lead) * radius
	target = room.clamp_to_floor(target + _separation(), ORBIT_WALL_MARGIN)
	var to_target := target - position
	if to_target.length() <= ORBIT_ARRIVE:
		return
	# Backing off it matches the player's walking pace, so it keeps a steady distance from a
	# player walking at it instead of darting off and stopping.
	var fly_speed := Tuning.player_speed if backing_off else speed
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

# Its attack is over (finished, or cut short by a stun): every other dragon in the room waits
# at least Tuning.wyrm_pack_attack_gap before attacking, so their attacks don't come one on
# the heels of another.
func _hold_off_other_dragons() -> void:
	var gap := Tuning.wyrm_pack_attack_gap * Tuning.enemy_attack_cooldown_multiplier
	for node in room.get_children():
		var other := node as Wyrm
		if other != null && other != self && other.attack_cooldown.time_left < gap:
			other.attack_cooldown.start(gap)

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
	_hold_off_other_dragons()

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
	_breath_glint_at = -1
	Juice.play(_breath_sound, 0.05, BREATH_PITCH * voice_pitch)

func _breath_held() -> bool:
	return _animation_is("shoot") && !_breath_timer.is_stopped()

# Rearing back or holding its breath: the fireball isn't out yet.
func _charging_fireball() -> bool:
	return _animation_is("shoot") && animator.frame < attack_frame

# The warning glow, quickening as the breath comes, and Tuning.wyrm_breath_parry_window
# before it the glint at its mouth that a parry is timed on.
func _pulse_breath(delta: float) -> void:
	if !_breath_glinted && _breath_timer.time_left <= Tuning.wyrm_breath_parry_window:
		_breath_glinted = true
		_breath_glint_at = Time.get_ticks_msec()
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

func breathe_fire() -> void:
	if !is_player_in_room():
		return
	Juice.play($Attack, 0.08, voice_pitch)
	var fireball: Projectile = Fireball.instantiate()
	room.add_child(fireball)
	fireball.position = room.clamp_to_floor(position + _mouth_offset(), Projectile.SPAWN_MARGIN)
	_fireball = fireball
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
	# Fresh windup: it hangs still in its lunge pose for a few seconds, a clear warning.
	_restart_attack(randf_range(Tuning.wyrm_charge_hold_min,
		maxf(Tuning.wyrm_charge_hold_min, Tuning.wyrm_charge_hold_max)))
	_unparryable = heavy
	_dashing = false
	_dash_left = 0.0

func _aim_charge() -> void:
	var to_player := _to_player()
	_charge_dir = to_player.normalized() if to_player != Vector2.ZERO else Direction.to_vector(direction)
	_face_along(_charge_dir)
	_hitbox_pivot.rotation = _charge_dir.angle()

# The windup hold ends by setting off on the charge, glinting as it goes (see _glint).
func _twinkle() -> void:
	if _animation_is("slash") && !_dashing:
		_begin_dash()
		_glint()
	else:
		super()

# The charge's glint, white or red, at the start of the dash. Unlike other enemies it opens
# no fixed window: the lunge pose holds until the charge reaches the player and bites, and
# any swing begun after the glint that meets it before then parries it (_parry_timing).
func _glint() -> void:
	_twinkled_at = Time.get_ticks_msec()
	Juice.twinkle(self, _twinkle_position(),
		UNPARRYABLE_TWINKLE_COLOR if _unparryable else Color(0, 0, 0, 0))

func _begin_dash() -> void:
	_aim_charge() # Re-aimed now, so the hold isn't a free head start to dodge
	_dashing = true
	_dash_left = minf(_to_player().length() + Tuning.wyrm_charge_overshoot, Tuning.wyrm_charge_max_distance)
	Juice.play(_charge_sound, 0.08, CHARGE_PITCH * voice_pitch)

func _charge(delta: float) -> void:
	if _dashing && _dash_left > 0:
		var step := minf(Tuning.wyrm_charge_speed * delta, _dash_left)
		var collision := move_and_collide(_charge_dir * step)
		_dash_left -= step
		# The side walls hold it back by margin rather than by collision (see
		# Enemy._keep_off_side_walls), so being pushed back off one counts as hitting it too.
		var before_clamp := position.x
		_keep_off_side_walls()
		if collision != null || !is_equal_approx(position.x, before_clamp):
			_slam_into_wall()
			return
	# Reached the player (or the end of the charge, dodged): it bites at once, going straight
	# to the bite frame. Playing on from the lunge pose, it would fly through them before the
	# bite came round.
	if _dashing && animator.frame < attack_frame && (_ahead_of_strike() <= 0 || _dash_left <= 0):
		_end_windup_hold()
		animator.frame = attack_frame
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

# A charge has no fixed parry window (see _glint): any swing begun after the glint that
# connects up to the bite parries it, rather than counting as late.
func _parry_timing() -> Parry:
	var timing := super()
	if timing == Parry.LATE && _animation_is("slash"):
		return Parry.IN_WINDOW
	return timing

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
	# Unlike other enemies, a stunned dragon takes no extra damage from the next hit
	# (Tuning.stagger_damage_multiplier): the stun itself is the reward.
	_set_vulnerable(false)
	_dashing = false
	_dash_left = 0.0
	_roll_cooldown()
	_hold_off_other_dragons()

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
