extends Enemy

# Goblin and Knight. Once the player enters its detection zone, or hits it from anywhere
# (an arrow from across the room), it fights until the player leaves the room. A knight
# (only_hit_during_attack) blocks any hit that lands outside its slash and is stunned for a
# second afterwards.
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
# Enemies whose sprites have them also react to hits: "block" plays once when a hit is
# shrugged off, and "vuln" flashes while invincible after a hit lands. The enemy stands
# still until the reaction is over.

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

@export var only_hit_during_attack: bool
@export var starting_direction := Direction.RIGHT
@export var double_attack := false # Some swings follow up when parried; see above
@export var unparryable_attack := false # Some swings can't be parried; see above

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
var _follow_up_ready := false # This swing is the first of a double attack
var _end_lag: Timer # Running while frozen at the end of an unparryable attack
var _end_lagged := false # This swing has had its end lag
var _turning := false # Swapping a swing's facing; its frame changes aren't real ones

@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var detection_zone: Area2D = $DetectionZonePivot/DetectionZone

func _ready() -> void:
	super()
	_end_lag = _add_timer(_on_end_lag_over)
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
	var coordinator := AttackCoordinator.for_room(room)
	if engaged:
		coordinator.check_in(self)
	var attacker := engaged && coordinator.is_attacker(self)
	_update_turn(coordinator, attacker)

	if !_animation_is("slash"): # Committed to a swing's facing until it ends
		_update_facing()
		_point_pivots()
	elif !_unparryable && _is_player_behind():
		_turn_mid_attack()

	if _is_reacting() || _animation_is("slash"):
		pass # Rooted while staggered, flinching or swinging
	elif engaged && attacker:
		_fight(coordinator, delta)
	elif engaged:
		_circle(coordinator, delta)

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
		&& (noticed || detection_zone.get_overlapping_bodies().has(player))

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
		if _can_start_swing(coordinator):
			_start_swing(_slot_horizontal)
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
	for horizontal in [true, false]:
		if _in_strike_position(horizontal) && _can_start_swing(coordinator):
			_start_swing(horizontal)
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
	_mark_attack_start()
	_play("slash")
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

# Where to stand to fight: the shorter of this enemy's slash reach (onto the player's
# hurtbox) and the player's sword reach (onto this enemy's hurtbox), less
# Tuning.engage_margin, so both sides' hits connect. Measured from the scenes' shapes.
func _engage_distance(horizontal: bool) -> float:
	if !_reach_cache.has(horizontal):
		var mine := _forward_reach(hitbox, self) + _half_extent(player.hurtbox, player, horizontal)
		var theirs := _forward_reach(player.hitbox, player) + _half_extent(hurtbox, self, horizontal)
		_reach_cache[horizontal] = minf(mine, theirs)
	return maxf(_reach_cache[horizontal] - Tuning.engage_margin, MIN_ENGAGE)

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
	_end_lag.stop()
	var block_stun: Timer = get_node_or_null("BlockStun")
	if block_stun != null:
		block_stun.stop()

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
	if !in_end_lag(): # Stays in the pose; the hit flash still shows
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
