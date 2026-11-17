class_name MeleeEnemy
extends Enemy

# Goblin and Knight. Once the player enters its detection zone, or hits it from anywhere
# (an arrow from across the room), it fights until the player leaves the room. A knight
# (only_hit_during_attack) blocks any hit that lands outside its slash and is stunned for
# Tuning.knight_block_stun afterwards. Knights sit out guarding, chip damage and the
# per-facing slash reach (see below), which are goblins only.
#
# Fighting: the enemy whose turn it is (see AttackCoordinator) walks to a spot beside the
# player, straight left, right, above or below, at a distance where its slash and the
# player's sword both connect, then stands its ground and swings. In a group, the others
# circle the player out of reach, spread apart, drifting at random; after a swing or two the
# attacker backs out to the circle and, after a random gap, another steps in. A lone enemy
# keeps the turn and swings whenever its cooldown allows. Nobody moves or turns mid-swing,
# and nobody starts a swing while another enemy is partway through one, so the player only
# ever has one windup to parry.
#
# Unparryable attacks (unparryable_attack, knights): some swings, Tuning.unparryable_chance of
# them, glint red instead of white and can't be parried; see Enemy._on_player_sword. The
# player has to roll through the enemy and hit it from behind. The enemy doesn't turn to
# follow them until the attack is over. Afterwards it's stuck in end lag: frozen on the
# attack's last frame for Tuning.heavy_end_lag, unable to move, turn or attack, and hits
# don't knock it out of the pose (no stun, though: no stars, no extra damage).
#
# Any other attack turns round if the player gets behind the enemy at any point in it,
# windup or follow-through, carrying on the same swing; the blade is still live after the
# strike, so a player who rolls through gets caught by it. Rolling through only beats
# unparryable attacks.
#
# Double attacks (double_attack, goblins): some swings, Tuning.double_attack_chance of them,
# come with a follow-up. Parrying the first doesn't stagger the enemy; it swings again
# straight away, glinting Tuning.double_attack_hold after the parry, and only parrying that
# second swing staggers it. A first swing that isn't parried is just a single attack.
#
# Pressure, so the player can't rush in swinging (no knockback stops it being pushed out of
# range either): it notices a player within its detection_radius anywhere but behind it,
# and alerts the rest of the room nearby. It starts its windup as soon as a player closing
# in gets within Tuning.threat_reach of its swing distance, rather than waiting for them to
# line up, and keeps re-aiming during the windup if they step round to its side. A hit
# that isn't a parry (sneaking up, or catching it recovering) gets a counter: it swings
# straight back, cooldown or not, so a second swing meets its windup and is blocked unless
# timed as a parry. One free hit, then the player has to parry.
#
# Guarding (not knights, which block their own way): a sword hit that lands before the
# enemy has started a swing is blocked, not taken, as long as it's seen the player coming
# and isn't hit from behind. A block still takes Tuning.chip_damage off it, like every
# other blocked hit (see Enemy._chip), and it swings straight back, cooldown or not (the same counter as
# above, but with no flinch if it can't), so a chip can't be followed by another: the next
# swing meets the counter's windup and is blocked, staggering the player, unless timed as a
# parry. Hits in a swing's recovery, from behind or from arrows aren't blocked this way.
#
# Hesitation (off unless a scene sets it): engage_hesitation_min/max hold a lined-up enemy
# back for a random moment before it swings, and rush_windup_chance makes it only sometimes
# start a windup at a player rushing in.
#
# Enemies whose sprites have them also react to hits: "block" plays once when a hit is
# shrugged off, and "vuln" flashes while invincible after a hit lands. The enemy stands
# still until the reaction is over.
#
# Roaming (roam_mode, off unless a room sets it): until it notices the player, the enemy
# walks instead of standing still, at Tuning.roam_speed, facing the way it walks (so its
# detection half-circle sweeps with it). PATH walks from where it starts through each
# point of roam_path and back again, over and over, pausing at each end. AREA wanders
# between random spots inside roam_area, pausing at each. Noticing the player (seeing them,
# being hit by anything, an arrow included, or being alerted by another enemy) ends it, and
# it fights as usual. It only roams while the player is in its room; leaving resets it to
# where it started, like everything else.

const SLOT_TOLERANCE := 6.0 # Pixels off the player's row or column that still lines up a swing
const ARRIVE_DISTANCE := 3.0 # Pixels from a circle target that count as there
const SLOT_ARRIVE := 0.5 # Pixels from the attack spot that count as there
const SLOT_PREFERENCE := 0.6 # Distance multiplier for the attack spot it's already heading for
const MIN_ENGAGE := 12.0 # Never tries to stand closer than this to the player
const AXIS_STICKINESS := 1.3 # How much the other axis must dominate before switching sides
const ORBIT_LEAD := 0.5 # Radians ahead along the circle a drifting enemy aims for
const MAX_ANGLE_STEP := 0.8 # Radians: the most the circle target leads the enemy by
const ORBIT_CHANGE_MIN := 1.0 # Seconds before picking a new drift (clockwise, anticlockwise, still)
const ORBIT_CHANGE_MAX := 3.0
const RING_WALL_MARGIN := 14.0 # Circle targets stay this far inside the floor
const RING_CRAMPED := 0.8 # Share of the circle's radius a wall can squash it to before moving round
const WALL_PUSH := 0.6 # Radians: how hard a cramped enemy slides round towards open floor
const WALL_PROBE := 0.4 # Radians either side checked for more room
const FOLLOW_UP_FLASH := Color(1, 0.6, 0.3) # Shown as a parried double attack swings again
const RUSH_SPEED := 20.0 # Pixels/sec towards the enemy that counts as the player closing in
const SLASH_COVER_MARGIN := 3.0 # Pixels the slash reaches past the player's sword; see _cover_player_reach

const DEFAULT_DETECTION_RADIUS := 64.0

enum Roam { NONE, PATH, AREA }
const ROAM_ARRIVE := 1.5 # Pixels from a roam target that count as there
const ROAM_STUCK_TIME := 1.0 # Seconds without getting anywhere before giving up on a roam target
const ROAM_AREA_MARGIN := 4.0 # Pixels inside roam_area that wander spots keep to
const ROAM_PICK_TRIES := 12 # Random spots tried for open floor before waiting and trying again

@export var only_hit_during_attack: bool
# Pixels: notices a player this close anywhere but behind it (see _sees_player_nearby).
# Set per enemy in each room; the room creator draws it as a circle you can drag.
@export_range(0, 400, 1) var detection_radius := DEFAULT_DETECTION_RADIUS
# Slash length worked out for each facing (true), or one length that covers the worst
# facing, used every way (false). See _cover_player_reach.
@export var per_facing_reach := true
@export var starting_direction := Direction.RIGHT
@export var double_attack := false # Some swings follow up when parried; see above
@export var unparryable_attack := false # Some swings can't be parried; see above
# Seconds it waits, lined up and ready, before swinging; rolled again for each swing.
@export var engage_hesitation_min := 0.0
@export var engage_hesitation_max := 0.0
# Chance it starts a windup at a player rushing into range; rolled once per approach.
@export_range(0, 1) var rush_windup_chance := 1.0
# What it does before noticing the player; see Roaming above. Set per enemy in each room
# with the room creator.
@export var roam_mode := Roam.NONE
# PATH: room-local positions (like `position`) it walks through after its starting spot.
@export var roam_path := PackedVector2Array()
# AREA: room-local rectangle its feet wander in.
@export var roam_area := Rect2()

const GUARD_FLASH := Color(0.75, 0.85, 1) # A goblin catching a hit on its blade
const GUARD_SPARK := Color(1, 0.9, 0.5)

# Hit by the player, or saw them, while they're in this room: it fights even outside its
# detection zone, until the player leaves the room.
var noticed := false

var _moving := false # Walked this physics frame; picks walk over idle
var _was_attacker := false
var _swings_left := 0 # Swings left in this turn (groups only)
var _slot_horizontal := true # Lining up beside the player (true) or above/below
var _orbit_dir := 0.0 # -1, 0 or 1: drift around the circle
var _orbit_change_in := 0.0
var _reach_cache := {} # Horizontal (bool) -> engage distance
var _reach_by_dir := {} # Direction -> pixels from the origin the slash reaches that way
var _slash_near := 0.0 # Local x of the slash hitbox's back edge, whichever way it reaches
var _follow_up_ready := false # This swing is the first of a double attack
var _end_lag: Timer # Running while frozen at the end of an unparryable attack
var _end_lagged := false # This swing has had its end lag
var _turning := false # Swapping a swing's facing; its frame changes aren't real ones
var _was_noticed := false # noticed, last physics frame
var _counter_pending := false # Just hit; swing back on the next physics frame
var _block_counter_pending := false # Just blocked a sword; swing back on the next physics frame
var _hesitation_left := -1.0 # Seconds before swinging; -1 until rolled for this swing
var _rush_roll := -1 # 1 if it winds up at the player's current rush, 0 if not, -1 unrolled
var _roam_home := Vector2.ZERO # Where it starts: the first point of a PATH
var _roam_index := 1 # PATH: point heading for, 0 being _roam_home
var _roam_step := 1 # PATH: +1 heading out along the path, -1 heading back
var _roam_target := Vector2.ZERO # Room-local position heading for
var _has_roam_target := false
var _roam_wait := 0.0 # Seconds left standing still before walking on
var _roam_stuck := 0.0 # Seconds without getting closer to _roam_target

@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var detection_zone: Area2D = $DetectionZonePivot/DetectionZone

func _ready() -> void:
	super()
	_end_lag = _add_timer(_on_end_lag_over)
	_cover_player_reach.call_deferred() # Once the player's shapes are in place
	_roam_home = position
	direction = starting_direction
	_play("idle")

func _process(_delta: float) -> void:
	if !player.in_transition:
		_update_windup()
		if !_animation_is("slash"):
			hitbox.disabled = true
		if !_is_reacting():
			animate()
	else:
		_play("idle")

func _physics_process(delta: float) -> void:
	_moving = false
	if player.in_transition:
		return
	if !is_player_in_room():
		noticed = false

	var engaged := is_detected()
	if engaged:
		noticed = true # Keeps fighting while circling outside the detection zone
	if noticed && !_was_noticed:
		_alert_pack()
	_was_noticed = noticed
	var coordinator := AttackCoordinator.for_room(room)
	if engaged:
		coordinator.check_in(self)
	var attacker := engaged && coordinator.is_attacker(self)
	_update_turn(coordinator, attacker)

	if _counter_pending:
		_counter_pending = false
		_counter(coordinator)
	if _block_counter_pending:
		_block_counter_pending = false
		_counter(coordinator, false)

	if !_animation_is("slash"): # Committed to a swing's facing until it ends
		_update_facing()
		_point_pivots()
	elif !_unparryable && (_is_player_behind() || _windup_off_target()):
		_turn_mid_attack()

	if _is_reacting() || _animation_is("slash"):
		pass # Rooted while staggered, flinching or swinging
	elif engaged && attacker:
		_fight(coordinator, delta)
	elif engaged:
		_circle(coordinator, delta)
	elif _can_roam():
		_roam(delta)

	_apply_knockback(delta)

# Turns to track the player while alerted. The two branches gate the room check
# differently, which is kept from the original.
func _update_facing() -> void:
	var alerted := is_detected() || invincibility_cooldown.time_left != 0
	var blocking: bool = only_hit_during_attack && $Block.playing
	if _is_player_mostly_horizontal() && (alerted || blocking) && is_player_in_room():
		_face_player_horizontally()
	elif alerted || (blocking && is_player_in_room()):
		_face_player_vertically()

func _point_pivots() -> void:
	$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)
	$DetectionZonePivot.rotation_degrees = Direction.to_rotation_degrees(direction)
	_fit_slash_to_facing()

func animate() -> void:
	if _animation_is("slash") && animator.frame == attack_end_frame:
		_play("idle")
		_on_swing_finished()

	if _animation_is("slash"):
		return
	if _moving:
		_play("walk")
	else:
		_play("idle")

func attack() -> void:
	if animator.visible:
		attack_cooldown.start(attack_cooldown_length)

# True when the player is in this room, not down a pitfall, and either inside the detection
# zone or has been noticed. The room check stops enemies next door chasing or slashing
# through the shared wall.
func is_detected() -> bool:
	return room.player_active && is_player_in_room() \
		&& (noticed || _sees_player_nearby() || detection_zone.get_overlapping_bodies().has(player))

# Within detection_radius, in front or to the side. Only the detection zone covers
# behind, so the player can still sneak up for a hit.
func _sees_player_nearby() -> bool:
	var offset := _to_player()
	return offset.length() <= detection_radius && Direction.to_vector(direction).dot(offset) >= 0

# Noticed the player: so does everyone else in the room within Tuning.alert_radius.
func _alert_pack() -> void:
	if !is_player_in_room():
		return
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self && "noticed" in other && other.room == room \
				&& other.position.distance_to(position) <= Tuning.alert_radius:
			other.noticed = true

# --- Taking turns (AttackCoordinator) ---

# Partway through a slash, up to the frame it strikes on.
func is_swinging() -> bool:
	return _animation_is("slash") && animator.frame <= attack_frame

func can_take_turn() -> bool:
	return !is_stunned()

# A new turn rolls how many swings it lasts; a turn whose swings are spent (or that was cut
# short by a parry) ends once the enemy is back on its feet. Alone, it never ends.
func _update_turn(coordinator: AttackCoordinator, attacker: bool) -> void:
	if attacker && !_was_attacker:
		_swings_left = randi_range(Tuning.pack_swings_min, maxi(Tuning.pack_swings_min, Tuning.pack_swings_max))
		_slot_horizontal = _is_player_mostly_horizontal()
	_was_attacker = attacker
	if attacker && _swings_left <= 0 && coordinator.member_count() > 1 \
			&& !is_stunned() && !_animation_is("slash"):
		coordinator.end_turn(self)
		_was_attacker = false

func _on_swing_finished() -> void:
	_swings_left -= 1

# Walks to the attack spot beside the player, then swings once lined up.
func _fight(coordinator: AttackCoordinator, delta: float) -> void:
	if _in_strike_position(_slot_horizontal):
		if _can_start_swing(coordinator) && _done_hesitating(delta):
			_start_swing(_slot_horizontal)
		return
	if _player_rushing_in() && _can_start_swing(coordinator):
		_start_swing(_is_player_mostly_horizontal())
		return
	_walk_to(_pick_slot(), speed, delta, SLOT_ARRIVE)

# The attack spot to head for: one of the four beside the player (left, right, above,
# below), skipping any with a pit or rock underfoot. Prefers the side it's already lining
# up on, so it doesn't dither near a diagonal, otherwise the nearest.
func _pick_slot() -> Vector2:
	var centre := _player_position()
	var from_player := position - centre
	_pick_slot_axis(from_player)
	var nav := room.nav()
	var best := Vector2.ZERO
	var best_score := INF
	for side: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var horizontal := side.y == 0
		var slot := centre + side * _engage_distance(horizontal)
		if !nav.is_open(slot + _feet()):
			continue
		var score := position.distance_to(slot)
		var preferred_side := signf(from_player.x if horizontal else from_player.y)
		if horizontal == _slot_horizontal && (side.x if horizontal else side.y) == preferred_side:
			score *= SLOT_PREFERENCE
		if score < best_score:
			best = slot
			best_score = score
			_slot_horizontal = horizontal
	if best_score == INF: # Boxed in on every side; just head for the player
		return centre
	return best

# Waits its turn on a circle around the player, spaced out from the others and drifting
# at random. Swings anyway if the player walks into reach and nobody else is swinging.
func _circle(coordinator: AttackCoordinator, delta: float) -> void:
	for horizontal: bool in [true, false]:
		if _in_strike_position(horizontal) && _can_start_swing(coordinator):
			if _done_hesitating(delta):
				_start_swing(horizontal)
			return
	if _player_rushing_in() && _can_start_swing(coordinator):
		_start_swing(_is_player_mostly_horizontal())
		return

	var centre := _player_position()
	var offset := position - centre
	if offset.length() < 1.0:
		offset = Vector2.RIGHT
	var angle := offset.angle()

	# Pushed apart around the circle by anyone closer than an even share of it, the
	# attacker hardest so its way in stays clear.
	var members := coordinator.members()
	var spacing := TAU / maxi(members.size(), 2)
	var push := 0.0
	for other in members:
		if other == self:
			continue
		var gap := wrapf(angle - (other.position - centre).angle(), -PI, PI)
		if absf(gap) < spacing:
			var weight := 2.0 if coordinator.is_attacker(other) else 1.0
			push += (1.0 if gap >= 0 else -1.0) * (spacing - absf(gap)) * weight

	# With the player near a wall, its part of the circle is squashed against the wall;
	# slide round to wherever there's more room.
	if _ring_room(centre, angle) < Tuning.pack_ring_radius * RING_CRAMPED:
		var more_room := _ring_room(centre, angle + WALL_PROBE) > _ring_room(centre, angle - WALL_PROBE)
		push += WALL_PUSH if more_room else -WALL_PUSH
	
	_orbit_change_in -= delta
	if _orbit_change_in <= 0:
		_orbit_dir = [-1.0, 0.0, 1.0].pick_random()
		_orbit_change_in = randf_range(ORBIT_CHANGE_MIN, ORBIT_CHANGE_MAX)

	var step := clampf(push + _orbit_dir * ORBIT_LEAD, -MAX_ANGLE_STEP, MAX_ANGLE_STEP)
	var target := centre + Vector2.from_angle(angle + step) * Tuning.pack_ring_radius
	_walk_to(room.clamp_to_floor(target, RING_WALL_MARGIN), speed * Tuning.pack_circle_speed, delta)

# How far from `centre` the circle point at `angle` can be once kept off the walls.
func _ring_room(centre: Vector2, angle: float) -> float:
	var point := centre + Vector2.from_angle(angle) * Tuning.pack_ring_radius
	return room.clamp_to_floor(point, RING_WALL_MARGIN).distance_to(centre)

# Sticks with the side of the player it's lining up on unless the other axis clearly wins,
# so it doesn't dither near a diagonal.
func _pick_slot_axis(from_player: Vector2) -> void:
	var x := absf(from_player.x)
	var y := absf(from_player.y)
	if _slot_horizontal && y > x * AXIS_STICKINESS:
		_slot_horizontal = false
	elif !_slot_horizontal && x > y * AXIS_STICKINESS:
		_slot_horizontal = true

# Lined up with the player on that axis and close enough for both swings to land.
func _in_strike_position(horizontal: bool) -> bool:
	var from_player := position - _player_position()
	var along := absf(from_player.x) if horizontal else absf(from_player.y)
	var across := absf(from_player.y) if horizontal else absf(from_player.x)
	return along <= _engage_distance(horizontal) + SLOT_ARRIVE && across <= SLOT_TOLERANCE

# Within Tuning.threat_reach of the distance it swings from, along whichever axis the
# player is mostly off it on.
func _player_in_threat_range() -> bool:
	var horizontal := _is_player_mostly_horizontal()
	var offset := _to_player().abs()
	return (offset.x if horizontal else offset.y) <= _engage_distance(horizontal) + Tuning.threat_reach

# In threat range and moving (walking or rolling) towards it: they'll be in reach by the
# time the windup is, so it starts now instead of letting them swing first.
# Only rush_windup_chance of approaches set it off, rolled the first time this one does.
func _player_rushing_in() -> bool:
	if !_player_in_threat_range():
		_rush_roll = -1 # A fresh roll for the next approach
		return false
	var towards_me := -_to_player()
	if towards_me.length() <= 0.01 || player.velocity.dot(towards_me.normalized()) <= RUSH_SPEED:
		return false
	if _rush_roll < 0:
		_rush_roll = 1 if randf() < rush_windup_chance else 0
	return _rush_roll == 1

# Counts down a random engage_hesitation_min/max once it's ready to swing; true when it's
# waited long enough.
func _done_hesitating(delta: float) -> bool:
	if engage_hesitation_max <= 0:
		return true
	if _hesitation_left < 0:
		_hesitation_left = randf_range(engage_hesitation_min, maxf(engage_hesitation_min, engage_hesitation_max))
	_hesitation_left -= delta
	return _hesitation_left <= 0

# A hit that wasn't a parry: swing straight back, ignoring the attack cooldown, if the
# player is close and nobody else is mid-swing. Otherwise just flinch.
# `flinch` false (after a block) does nothing instead of flinching.
func _counter(coordinator: AttackCoordinator, flinch := true) -> void:
	if is_stunned() || in_end_lag() || _animation_is("slash") || !is_detected() \
			|| coordinator.other_is_swinging(self) || !_player_in_threat_range() \
			|| (only_hit_during_attack && $BlockStun.time_left != 0):
		if flinch:
			_play_reaction("vuln")
		return
	_start_swing(_is_player_mostly_horizontal())

# Mid-windup with the player stepped round to its side: worth turning to keep them in
# front. Sticky, like the attack spot, so a diagonal doesn't make it spin.
func _windup_off_target() -> bool:
	if animator.frame >= attack_frame:
		return false
	var offset := _to_player().abs()
	if direction == Direction.LEFT || direction == Direction.RIGHT:
		return offset.y > offset.x * AXIS_STICKINESS
	return offset.x > offset.y * AXIS_STICKINESS

func _can_start_swing(coordinator: AttackCoordinator) -> bool:
	if attack_cooldown.time_left != 0 || coordinator.other_is_swinging(self):
		return false
	return !only_hit_during_attack || $BlockStun.time_left == 0

func _start_swing(horizontal: bool) -> void:
	if horizontal:
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	_hesitation_left = -1.0
	_rush_roll = -1
	# Fresh windup, even straight out of an interrupted one that _update_windup hasn't
	# seen end yet (a counter).
	_end_windup_hold()
	_windup_held = false
	_twinkled_at = -1
	_mark_attack_start()
	_play("slash")
	animator.frame = 0
	attack()
	_unparryable = unparryable_attack && randf() < Tuning.unparryable_chance
	_end_lagged = false
	_follow_up_ready = !_unparryable && double_attack && randf() < Tuning.double_attack_chance

func in_end_lag() -> bool:
	return !_end_lag.is_stopped()

# The unparryable attack has swung through: freeze on its last frame, blade harmless.
func _start_end_lag() -> void:
	_end_lagged = true
	animator.pause()
	hitbox.disabled = true
	_end_lag.start(Tuning.heavy_end_lag)

# Plays out the last of the attack, back to idle.
func _on_end_lag_over() -> void:
	if _animation_is("slash"):
		animator.play()

func _hit_interrupts_attack() -> bool:
	return !in_end_lag()

func _is_player_behind() -> bool:
	return Direction.to_vector(direction).dot(_to_player()) < 0

# The player got behind mid-attack (rolled through): face them and carry on with the same
# swing, at the same point in it, held or not. The hitbox turns with it.
func _turn_mid_attack() -> void:
	var frame := animator.frame
	var held := !animator.is_playing()
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	_turning = true # Re-showing the same frame isn't a new strike
	_play("slash")
	animator.frame = frame
	_turning = false
	if held:
		animator.pause()

# The first swing of a double attack was parried: swing again at once. The player can
# swing again straight away too, cutting their parrying swing short, to meet it (or, too
# soon, to be blocked by it).
func _parried_follow_up() -> bool:
	if !_follow_up_ready:
		return false
	_follow_up_ready = false
	Juice.flash(animator, 0.12, FOLLOW_UP_FLASH)
	_restart_attack(Tuning.double_attack_hold)
	attack()
	player.allow_instant_swing()
	return true

# Where to stand to fight: on each side of the player along that axis, the shorter of this
# enemy's slash reach (onto the player's hurtbox) and the player's sword reach (onto this
# enemy's hurtbox); the shorter side wins, less Tuning.engage_margin, so both sides' hits
# connect. Measured from the scenes' shapes.
func _engage_distance(horizontal: bool) -> float:
	if !_reach_cache.has(horizontal) && !per_facing_reach: # Hurtbox offsets ignored
		var mine := _forward_reach(hitbox, self) + _half_extent(player.hurtbox, player, horizontal)
		var theirs := _forward_reach(player.hitbox, player) + _half_extent(hurtbox, self, horizontal)
		_reach_cache[horizontal] = minf(mine, theirs)
	if !_reach_cache.has(horizontal):
		var best := INF
		for dir: String in ([Direction.LEFT, Direction.RIGHT] if horizontal else [Direction.UP, Direction.DOWN]):
			var mine := _slash_gap(dir, _slash_reach(dir))
			best = minf(best, minf(mine, _sword_gap(dir)))
		_reach_cache[horizontal] = best
	return maxf(_reach_cache[horizontal] - Tuning.engage_margin, MIN_ENGAGE)

# Facing `dir` with the player straight that way: the furthest apart the two origins can
# be with the player's sword still reaching this enemy's hurtbox. The hurtboxes sit off
# their owners' origins (above them, mostly), which is why up and down differ.
func _sword_gap(dir: String) -> float:
	var v := Direction.to_vector(dir)
	return _forward_reach(player.hitbox, player) + _shape_centre(hurtbox, self).dot(v) \
		+ _half_extent(hurtbox, self, v.y == 0)

# The same for this enemy's slash reaching `reach` from its origin onto the player's hurtbox.
func _slash_gap(dir: String, reach: float) -> float:
	var v := Direction.to_vector(dir)
	return reach - _shape_centre(player.hurtbox, player).dot(v) + _half_extent(player.hurtbox, player, v.y == 0)

# Pixels from the origin the slash reaches facing `dir`; see _cover_player_reach.
func _slash_reach(dir: String) -> float:
	return _reach_by_dir.get(dir, _forward_reach(hitbox, self))

# The player's sword is broad: standing off on a diagonal, the player could catch a corner
# of this enemy's hurtbox from somewhere its own slash, aimed one of four ways, can't reach
# back. So the slash hitbox grows (never shrinking below the scene's) until, from anywhere
# the player's sword reaches this enemy, the slash reaches the player, plus
# SLASH_COVER_MARGIN. Forward, that's worked out for each facing on its own
# (_fit_slash_to_facing swaps the length in), so a slash isn't longer one way just because
# another way needs it. Across, it only has to cover as far off-axis as the player can be
# before the enemy would face the other way (about as far off as they are along).
func _cover_player_reach() -> void:
	if !is_instance_valid(player):
		return
	var sword_reach := _forward_reach(player.hitbox, player)
	var sword_half_width := _half_extent(player.hitbox, player, false) # Across the blade
	var need_half_width := 0.0
	for horizontal: bool in [true, false]:
		var mine_across := _half_extent(hurtbox, self, !horizontal)
		var theirs_across := _half_extent(player.hurtbox, player, !horizontal)
		var furthest_along := sword_reach + _half_extent(hurtbox, self, horizontal)
		var furthest_across := minf(sword_half_width + mine_across, furthest_along)
		need_half_width = maxf(need_half_width, furthest_across - theirs_across)

	var rect := (hitbox.shape as RectangleShape2D).duplicate() as RectangleShape2D
	var s := absf(scale.x)
	_slash_near = hitbox.position.x - rect.size.x / 2 # Local units, like the shape
	if per_facing_reach:
		var scene_reach := _forward_reach(hitbox, self)
		for dir: String in [Direction.RIGHT, Direction.LEFT, Direction.UP, Direction.DOWN]:
			var need := _sword_gap(dir) - _slash_gap(dir, 0.0) + SLASH_COVER_MARGIN
			_reach_by_dir[dir] = maxf(scene_reach, need)
	else: # One length, the longest either axis needs, hurtbox offsets ignored
		var need_reach := 0.0
		for horizontal: bool in [true, false]:
			need_reach = maxf(need_reach, sword_reach + _half_extent(hurtbox, self, horizontal)
				- _half_extent(player.hurtbox, player, horizontal))
		var far := (need_reach + SLASH_COVER_MARGIN) / s
		if far > _slash_near + rect.size.x:
			rect.size.x = far - _slash_near
			hitbox.position.x = (_slash_near + far) / 2
	rect.size.y = maxf(rect.size.y, 2 * (need_half_width + SLASH_COVER_MARGIN) / s)
	hitbox.shape = rect
	_reach_cache.clear()
	_fit_slash_to_facing()

# Stretches the slash hitbox to the reach worked out for the way it faces.
func _fit_slash_to_facing() -> void:
	if !_reach_by_dir.has(direction):
		return
	var rect := hitbox.shape as RectangleShape2D
	var far: float = _reach_by_dir[direction] / absf(scale.x)
	rect.size.x = far - _slash_near
	hitbox.position.x = (_slash_near + far) / 2

static func _shape_centre(shape: CollisionShape2D, owner_body: Node2D) -> Vector2:
	return shape.position * owner_body.scale.abs()

# How far in front of its owner a hitbox reaches (hitboxes point right before their pivot
# turns them).
static func _forward_reach(shape: CollisionShape2D, owner_body: Node2D) -> float:
	var rect := shape.shape as RectangleShape2D
	return (shape.position.x + rect.size.x / 2) * absf(owner_body.scale.x)

static func _half_extent(shape: CollisionShape2D, owner_body: Node2D, horizontal: bool) -> float:
	var rect := shape.shape as RectangleShape2D
	var size := rect.size.x * absf(owner_body.scale.x) if horizontal else rect.size.y * absf(owner_body.scale.y)
	return size / 2

# From the enemy's origin to the middle of its feet (its body's collision shape).
func _feet() -> Vector2:
	return ($CollisionShape2D as Node2D).position * scale

# The player's position in the room's space, which is the space `position` is in.
func _player_position() -> Vector2:
	return room.to_local(player.global_position)

# Heads for `target` (room space), round any pits and rocks in the way (Room.nav), sliding
# along whatever it still bumps into.
func _walk_to(target: Vector2, walk_speed: float, delta: float, arrive := ARRIVE_DISTANCE) -> void:
	if position.distance_to(target) <= arrive:
		return
	var feet := _feet()
	var waypoint := room.nav().next_waypoint(position + feet, target + feet) - feet
	var to_waypoint := waypoint - position
	var distance := to_waypoint.length()
	if distance < 0.01:
		return
	var motion := to_waypoint / distance * minf(walk_speed * delta, distance)
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	_moving = true

func _on_reset() -> void:
	noticed = false
	hitbox.disabled = true
	_was_attacker = false
	_swings_left = 0
	_moving = false
	_follow_up_ready = false
	_counter_pending = false
	_block_counter_pending = false
	_was_noticed = false
	_end_lag.stop()
	_hesitation_left = -1.0
	_rush_roll = -1
	var block_stun: Timer = get_node_or_null("BlockStun")
	if block_stun != null:
		block_stun.stop()
	_roam_index = 1
	_roam_step = 1
	_has_roam_target = false
	_roam_wait = 0.0
	_roam_stuck = 0.0

# --- Roaming (see the top of the file) ---

# Hasn't noticed the player, who is in the room (not down a pitfall), and has somewhere to go.
func _can_roam() -> bool:
	if noticed || !room.player_active || !is_player_in_room():
		return false
	match roam_mode:
		Roam.PATH: return !roam_path.is_empty()
		Roam.AREA: return roam_area.has_area()
	return false

func _roam(delta: float) -> void:
	if _roam_wait > 0:
		_roam_wait -= delta
		return
	if !_has_roam_target:
		_has_roam_target = _pick_roam_target()
		_roam_stuck = 0.0
		if !_has_roam_target: # Nowhere open to go; try again in a moment
			_roam_wait = Tuning.roam_pause_min
			return
	var before := position
	var distance_before := position.distance_to(_roam_target)
	var walk_speed := speed * Tuning.roam_speed
	_walk_to(_roam_target, walk_speed, delta, ROAM_ARRIVE)
	_face_roam(_roam_target - before)
	var distance_now := position.distance_to(_roam_target)
	if distance_now <= ROAM_ARRIVE:
		_roam_arrived()
		return
	# Blocked by a wall or another enemy, or only creeping along one: give up on this spot
	# after a while.
	var progress := distance_before - distance_now
	_roam_stuck = 0.0 if progress >= walk_speed * delta * 0.25 else _roam_stuck + delta
	if _roam_stuck >= ROAM_STUCK_TIME:
		_roam_arrived()

# PATH: the next point along it. AREA: a random open spot in the area. False if there's none.
# Either way kept side_wall_margin off the side walls, where it can't go.
func _pick_roam_target() -> bool:
	if roam_mode == Roam.PATH:
		_roam_target = _off_side_walls(_roam_point(_roam_index))
		return true
	var area := roam_area.grow(-ROAM_AREA_MARGIN)
	if !area.has_area():
		area = roam_area
	var feet := _feet()
	var nav := room.nav()
	for i in range(ROAM_PICK_TRIES):
		var spot := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		if nav.is_open(spot):
			_roam_target = _off_side_walls(spot - feet)
			return true
	return false

func _off_side_walls(point: Vector2) -> Vector2:
	if side_wall_margin > 0:
		var floor_rect := room.floor_rect
		point.x = clampf(point.x, floor_rect.position.x + side_wall_margin, floor_rect.end.x - side_wall_margin)
	return point

# PATH point `i`: 0 is where it started, then roam_path's points in order.
func _roam_point(i: int) -> Vector2:
	return _roam_home if i == 0 else roam_path[i - 1]

# Reached its target (or gave up on it). On a PATH, moves on to the next point, turning
# round at each end and pausing there; in an AREA, pauses before picking a new spot.
func _roam_arrived() -> void:
	_has_roam_target = false
	if roam_mode == Roam.PATH:
		var last := roam_path.size() # Index of the far end; 0 is the near one
		var at_end := _roam_index == 0 || _roam_index == last
		if _roam_index + _roam_step < 0 || _roam_index + _roam_step > last:
			_roam_step = -_roam_step
		_roam_index = clampi(_roam_index + _roam_step, 0, last)
		if !at_end:
			return
	_roam_wait = randf_range(Tuning.roam_pause_min, maxf(Tuning.roam_pause_min, Tuning.roam_pause_max))

# Faces the way it's heading (sticky near a diagonal, so it doesn't flicker), drawn in front
# of the player when below them.
func _face_roam(heading: Vector2) -> void:
	if heading.length() < 0.01:
		return
	var horizontal := direction == Direction.LEFT || direction == Direction.RIGHT
	if horizontal && absf(heading.y) > absf(heading.x) * AXIS_STICKINESS:
		horizontal = false
	elif !horizontal && absf(heading.x) > absf(heading.y) * AXIS_STICKINESS:
		horizontal = true
	if horizontal:
		direction = Direction.LEFT if heading.x < 0 else Direction.RIGHT
	else:
		direction = Direction.UP if heading.y < 0 else Direction.DOWN
	z_index = 10 if position.y > _player_position().y else 1
	_point_pivots()

# --- Guarding (see the top of the file) ---

func _on_player_sword(from_direction: String) -> void:
	if _can_guard(from_direction):
		_guard.call_deferred(from_direction, player.swing_started_frame)
	else:
		super(from_direction)

# Guards against the swing begun on physics frame `swing_frame`, unless it parried another
# enemy, in which case it passes through untouched (see Enemy._block_player_swing).
func _guard(from_direction: String, swing_frame: int) -> void:
	if !player.swing_parried(swing_frame):
		_block_sword(from_direction)

# Not a knight, not swinging (or recovering from one), not dazed, and facing a player it
# has already noticed. A swing the player started before this enemy's attack began counts
# as landing before it too, even if the windup has started by the time it connects.
func _can_guard(from_direction: String) -> bool:
	if only_hit_during_attack || invincibility_cooldown.time_left != 0:
		return false
	if _animation_is("slash") && !_in_windup_swung_first():
		return false
	if is_stunned() || is_vulnerable() || in_end_lag():
		return false
	return noticed && from_direction != direction # The sword travelling its way is from behind

func _in_windup_swung_first() -> bool:
	return _animation_is("slash") && animator.frame <= attack_frame && _swung_first()

func _block_sword(from_direction: String) -> void:
	if is_player_in_room():
		noticed = true
	if _animation_is("slash"): # Its windup started under the player's swing; drop it to block
		_end_windup_hold()
		_play("idle")
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	var hit_dir := Direction.to_vector(from_direction)
	Juice.burst(room, global_position - hit_dir * 6, GUARD_SPARK, 6, 70.0, -hit_dir, 1.5, 0.25)
	Juice.hitstop(HITSTOP_BLOCK)
	Juice.shake(Juice.SHAKE_LIGHT)
	Juice.clank(true)
	Juice.flash(animator, 0.1, GUARD_FLASH)
	_chip(hit_dir)
	_block_counter_pending = Tuning.counter_attack # Swings back next physics frame

# Knights take no chip damage; their blocks are the old, free kind.
func _chip(hit_dir: Vector2) -> void:
	if !only_hit_during_attack:
		super(hit_dir)

# Any hit, even one a knight blocks, gives the player away.
func take_damage(from_direction: String, amount: float) -> void:
	if is_player_in_room():
		noticed = true
	super(from_direction, amount)
	if in_end_lag():
		knockback = Vector2.ZERO # Planted until the end lag is over

func _blocks_hit() -> bool:
	if only_hit_during_attack && !_animation_is("slash"):
		$BlockStun.start(Tuning.knight_block_stun)
		Juice.play($Block)
		_play_reaction("block")
		return true
	return false

func _after_hit() -> void:
	if in_end_lag(): # Stays in the pose; the hit flash still shows
		return
	if Tuning.counter_attack && !is_stunned():
		_counter_pending = true # Swings back next physics frame, or flinches; see _counter
	else:
		_play_reaction("vuln")

# Plays a hit reaction if this enemy's sprites have one. It uses the enemy's own facing,
# not the hit's direction that take_damage shows when it interrupts a slash, so the enemy
# keeps looking at the player.
func _play_reaction(action: String) -> void:
	if animator.sprite_frames.has_animation(action + "_" + direction):
		_play(action)

# Parried: the turn is over once the stun wears off.
func _on_staggered() -> void:
	_swings_left = 0
	_play_reaction("vuln")

# True while stunned from a parry, in end lag, while a block plays out, or while flashing
# after a hit.
func _is_reacting() -> bool:
	if is_stunned() || in_end_lag():
		return true
	if _animation_is("block"):
		return animator.is_playing()
	if _animation_is("vuln"):
		return invincibility_cooldown.time_left != 0
	return false

func _lose_health(amount: float, critical: bool) -> void:
	if critical:
		Juice.play($Crit, 0.05)
	super(amount, critical)

func _on_animated_sprite_2d_frame_changed() -> void:
	if _turning:
		return
	if _animation_is("slash") && animator.frame == attack_frame:
		Juice.play($Attack)
		hitbox.disabled = false
	elif _animation_is("slash") && _unparryable && !_end_lagged && animator.frame == attack_end_frame - 1:
		_start_end_lag()
