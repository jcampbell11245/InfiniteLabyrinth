class_name Hobgoblin
extends MeleeEnemy

# A goblin that blows itself up on the player. It notices the player, alerts the room and
# roams as a goblin does (MeleeEnemy), but the moment it has noticed them it sprints straight
# at them: no turn to wait for, no circling, no pause. Once its body is within
# Tuning.hobgoblin_contact_reach of the player's (the gap between their hurtboxes) it stops dead
# and glints (white, at once, with no random windup hold), and when the glint's
# Tuning.parry_window runs out it goes off: a blast of Tuning.hobgoblin_blast_radius that
# hurts the player (rolling doesn't save them; only getting out of the blast does) and every
# enemy caught in it.
#
# A swing timed on the glint parries it as it would any attack, but instead of being
# stunned it's flung the way the sword travels, at Tuning.hobgoblin_fling_speed, and goes
# off when it hits another enemy, a wall or a rock, or after Tuning.hobgoblin_fling_time. A
# flung hobgoblin's blast never hurts the player, so parrying one into a crowd is the way to
# use it. A spin that catches it flings it too. A swing begun before the glint that meets it
# is blocked and staggers the player, as for any attack, and a late one does nothing.
#
# A hit as it runs in is an ordinary one (it doesn't guard), and one that kills it just
# kills it: it only goes off by reaching the player, after a parry, or when caught in
# another blast (one blast sets off any hobgoblin in it, which never hurts the player if the
# first didn't).

const BLAST_FIRE := Color(1, 0.55, 0.15)
const BLAST_SMOKE := Color(0.25, 0.22, 0.2, 0.8)
const BLAST_SPARKS := 30
const BLAST_PUFFS := 15
const BLAST_SPEED := 140.0
const BLAST_STAIN := 14.0 # Radius of the scorch it leaves
const BLAST_PITCH := 0.55 # Its attack sound, pitched right down, is the bang
const FLING_FLASH := Color(1, 0.4, 0.1) # Glows while flung, lit
const FLING_SPIN := 18.0 # Radians/sec it tumbles while flung
const FLING_HIT_REACH := 14.0 # Pixels between centres at which a flung one sets off on another enemy

var _fuse: Timer # Running from the glint to the blast
var _flung := false
var _fling_dir := Vector2.ZERO
var _fling_left := 0.0 # Seconds before a flung one goes off anyway
var _exploded := false

func _ready() -> void:
	super()
	_fuse = _add_timer(_on_fuse_out)

func _physics_process(delta: float) -> void:
	_moving = false
	if player.in_transition:
		return
	if _flung:
		_fly(delta)
		return
	if !is_player_in_room():
		noticed = false
	var engaged := is_detected()
	if engaged:
		noticed = true
	if noticed && !_was_noticed:
		_alert_pack()
	_was_noticed = noticed
	if engaged:
		AttackCoordinator.for_room(room).check_in(self) # Others hold off while it glints
	if !is_fusing():
		_update_facing()
		_point_pivots()
	if is_fusing():
		pass # Rooted, glinting
	elif engaged:
		_run_in(delta)
	elif _can_roam():
		_roam(delta)
	_apply_knockback(delta)

# Sprints at the player and lights up the moment it reaches them.
func _run_in(delta: float) -> void:
	if _gap_to_player() <= Tuning.hobgoblin_contact_reach:
		_light_fuse()
		return
	_walk_to(_player_position(), speed, delta, 0.0)

# Stops, faces the player and glints straight away; the blast comes when the parry window
# closes (_on_fuse_out).
func _light_fuse() -> void:
	knockback = Vector2.ZERO # Stops dead where it is
	slide = Vector2.ZERO
	velocity = Vector2.ZERO
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	_end_windup_hold()
	_mark_attack_start()
	_play("slash")
	animator.frame = maxi(attack_frame - 1, 0)
	animator.pause()
	_windup_held = true # Its glint is now, not after a random hold (Enemy._update_windup)
	_twinkle()
	_fuse.start(ItemEffects.parry_window())
	Juice.play($Attack, 0.08, voice_pitch)

# Pixels between its hurtbox and the player's, along whichever axis they're further apart
# on; 0 or less once they touch. Measured between bodies rather than centres, so it stops as
# it reaches the player instead of running on into them.
func _gap_to_player() -> float:
	var offset := (player.global_position + _shape_centre(player.hurtbox, player)) \
		- (global_position + _shape_centre(hurtbox, self))
	var gap_x := absf(offset.x) - _half_extent(player.hurtbox, player, true) - _half_extent(hurtbox, self, true)
	var gap_y := absf(offset.y) - _half_extent(player.hurtbox, player, false) - _half_extent(hurtbox, self, false)
	return maxf(gap_x, gap_y)

func is_fusing() -> bool:
	return !_fuse.is_stopped()

func _on_fuse_out() -> void:
	if !_flung && !_exploded:
		explode(true)

# Never takes a melee turn or joins a group rush: it comes on its own clock.
func can_take_turn() -> bool:
	return false

# Glinting: others hold off their own windups.
func is_swinging() -> bool:
	return is_fusing()

# Its glint is timed like any attack's (Enemy._on_player_sword); flung or gone, nothing.
func _on_player_sword(from_direction: String) -> void:
	if _flung || _exploded:
		return
	super(from_direction)

# It doesn't guard; see the top of the file.
func _can_guard(_from_direction: String) -> bool:
	return false

func _guards_spin(_from_direction: String) -> bool:
	return false

# A hit while it glints (an arrow) doesn't stop the blast.
func _hit_interrupts_attack() -> bool:
	return !is_fusing()

# Parried (or spun into): flung the way the hit travels, lit.
func stagger(from_direction: String, _stun_time := -1.0) -> void:
	_fling(Direction.to_vector(from_direction))

func _fling(dir: Vector2) -> void:
	_end_windup_hold()
	_fuse.stop()
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
				&& other.global_position.distance_to(global_position) <= FLING_HIT_REACH:
			return true
	return false

# Goes off: everything within Tuning.hobgoblin_blast_radius is caught, the player too if
# `hurts_player`. It dies in it.
func explode(hurts_player: bool) -> void:
	if _exploded:
		return
	_exploded = true
	_fuse.stop()
	var at := global_position
	Juice.burst(room, at, BLAST_FIRE, BLAST_SPARKS, BLAST_SPEED, Vector2.ZERO, 2.5, 0.45)
	Juice.burst(room, at, BLAST_SMOKE, BLAST_PUFFS, BLAST_SPEED / 2, Vector2.UP, 3.0, 0.7)
	Juice.splat(room, at + FEET_OFFSET, BLAST_SMOKE.darkened(0.3), BLAST_STAIN)
	# On Juice, not its own player: it dies this frame, and its player with it.
	Juice.one_shot(($Attack as AudioStreamPlayer).stream, 0.05, BLAST_PITCH * voice_pitch)
	Juice.shake(Juice.SHAKE_HEAVY)
	Juice.hitstop(HITSTOP_KILL)
	for node in room.get_children():
		var other := node as Enemy
		if other == null || other == self || other.is_queued_for_deletion() \
				|| other.global_position.distance_to(at) > Tuning.hobgoblin_blast_radius:
			continue
		if other is Pilot && (other as Pilot).mount != null:
			continue # Riding: the blast reaches it through its mount (Enemy._rider_absorbs)
		if other is Hobgoblin:
			(other as Hobgoblin).caught_in_blast(hurts_player)
		else:
			other.hurt_by_blast(at, Tuning.hobgoblin_blast_enemy_damage)
	var to_player := player.global_position - at
	if hurts_player && to_player.length() <= Tuning.hobgoblin_blast_radius:
		player.take_damage(blast_damage(), _nearest_direction(to_player), false)
	health = 0
	die()

# Damage its blast does to the player. It doesn't go through `damage` (it has no slash), so it
# applies the F2 enemy damage multiplier and a server's attack boost itself, as `damage` would.
func blast_damage() -> float:
	return Tuning.hobgoblin_blast_damage * Tuning.enemy_damage_multiplier \
		* buff_multiplier(ServerBuff.Kind.ATTACK)

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
	_fuse.stop()
	_flung = false
	animator.rotation = 0.0
	hurtbox.disabled = false
