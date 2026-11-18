class_name AttackCoordinator
extends Node

# Takes turns for a room's melee enemies so the player only has one attacker to read and
# parry at a time. Every melee enemy fighting the player checks in each physics frame; the
# coordinator hands one of them (Tuning.pack_max_attackers) the turn to step in and swing,
# and the rest circle at a distance. When a turn ends there's a random gap, then a random
# enemy (preferably not the one that just went) gets the next.
#
# Now and then several rush in at once instead; see Group rushes below.
#
# Lives as a child of its Room, made by the first enemy that asks (for_room). Members that
# stop checking in (dead, reset, gave up the chase) drop out on their own.

const NODE_NAME := "AttackCoordinator"
const STALE_FRAMES := 2 # A member that misses this many physics frames has left the fight
const TURN_RANGE := 1.4 # Turns go to members within this many circle radii of the player

var _last_seen := {} # Enemy -> physics frame of its last check-in
var _attackers: Array[Enemy] = []
var _turn_time := {} # Attacker -> seconds into its turn
var _last_attacker: Variant # Enemy, or null; may have been freed
var _gap := 0.0 # Seconds before the next turn can be handed out
var _rushers: Array[Enemy] = [] # In the group rush under way; see Group rushes
var _rush_time := 0.0 # Seconds since it started
var _rush_launched := false # Its swings have started
var _next_rush := -1.0 # Seconds of fighting until the next; -1 until rolled

# The coordinator for `room`, made on first use.
static func for_room(room: Node) -> AttackCoordinator:
	var existing := room.get_node_or_null(NODE_NAME) as AttackCoordinator
	if existing != null:
		return existing
	var made := AttackCoordinator.new()
	made.name = NODE_NAME
	room.add_child(made)
	return made

# Called every physics frame by an enemy that is fighting the player.
func check_in(enemy: Enemy) -> void:
	_last_seen[enemy] = Engine.get_physics_frames()

func members() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for enemy in _last_seen:
		if _alive(enemy):
			out.append(enemy)
	return out

func member_count() -> int:
	return _last_seen.size()

func is_attacker(enemy: Enemy) -> bool:
	return _attackers.has(enemy)

# The enemy's turn is over: it backs off, and after a random gap someone else steps in.
func end_turn(enemy: Enemy) -> void:
	if !_attackers.has(enemy):
		return
	_attackers.erase(enemy)
	_turn_time.erase(enemy)
	_last_attacker = enemy
	_gap = randf_range(Tuning.pack_turn_gap_min, maxf(Tuning.pack_turn_gap_min, Tuning.pack_turn_gap_max))

# True when another member is partway through a swing, so `enemy` should hold off
# starting its own and the player never has two windups to parry at once.
func other_is_swinging(enemy: Enemy) -> bool:
	for other in _last_seen:
		if other != enemy && _alive(other) && other.is_swinging():
			return true
	return false

func _physics_process(delta: float) -> void:
	_prune()
	_gap = maxf(_gap - delta, 0.0)
	if rush_active():
		_update_rush(delta)
		return
	if _update_rush_countdown(delta):
		return

	# A lone enemy always has the turn; there's no one to take over.
	if _last_seen.size() == 1:
		var only: Enemy = _last_seen.keys()[0]
		if !_attackers.has(only):
			_attackers.clear()
			_attackers.append(only)
			_turn_time[only] = 0.0
		return

	# An attacker that can't reach the player (blocked, kited) gives up its turn.
	for attacker in _attackers.duplicate():
		_turn_time[attacker] = _turn_time.get(attacker, 0.0) + delta
		if _turn_time[attacker] > Tuning.pack_turn_timeout && !attacker.is_swinging():
			end_turn(attacker)

	while _attackers.size() < Tuning.pack_max_attackers && _gap == 0:
		var next := _pick_next()
		if next == null:
			break
		_attackers.append(next)
		_turn_time[next] = 0.0
		if _attackers.size() < Tuning.pack_max_attackers:
			_gap = randf_range(Tuning.pack_turn_gap_min, maxf(Tuning.pack_turn_gap_min, Tuning.pack_turn_gap_max))

# A random member ready to fight and already near the player (on the circle, not still
# making its way over), avoiding whoever just had a turn if anyone else can go. If nobody
# is near yet, the nearest gets it, so the player isn't left waiting.
func _pick_next() -> Enemy:
	var ready: Array[Enemy] = []
	var nearest: Enemy = null
	var nearest_distance := INF
	var player_at: Vector2 = Game.player.global_position
	for enemy in _last_seen:
		if !_alive(enemy) || _attackers.has(enemy) || !enemy.can_take_turn():
			continue
		var distance: float = enemy.global_position.distance_to(player_at)
		if distance <= Tuning.pack_ring_radius * TURN_RANGE:
			ready.append(enemy)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if ready.is_empty():
		return nearest
	if ready.size() > 1 && ready.has(_last_attacker):
		ready.erase(_last_attacker)
	return ready.pick_random()

func _prune() -> void:
	var frame := Engine.get_physics_frames()
	for enemy in _last_seen.keys():
		if !_alive(enemy) || frame - _last_seen[enemy] >= STALE_FRAMES:
			_last_seen.erase(enemy)
	for attacker in _attackers.duplicate():
		if !_last_seen.has(attacker):
			_attackers.erase(attacker)
			_turn_time.erase(attacker)
	if !is_instance_valid(_last_attacker):
		_last_attacker = null

static func _alive(enemy: Variant) -> bool:
	return is_instance_valid(enemy) && !(enemy as Node).is_queued_for_deletion()

# --- Group rushes ---
# Every Tuning.group_rush_interval_min/max seconds of fighting, with at least
# Tuning.group_rush_min members in and nobody mid-swing, up to Tuning.group_rush_max of
# them (nearest first) are each given a different side of the player (left, right, above,
# below) and rush to it. Once all are in place (or Tuning.group_rush_gather_time runs out,
# dropping anyone not there yet) they start their swings together, each holding its windup
# for Tuning.group_rush_hold so the player has time to charge a spin attack. Turns are
# paused meanwhile, and nobody else starts a swing; once the rush's swings are over, turns
# pick up again after a gap. A rusher that's stunned (spun into, parried) drops out.

func rush_active() -> bool:
	return !_rushers.is_empty()

# Enemies in the group rush under way; 0 when there's none.
func rusher_count() -> int:
	return _rushers.size()

# Counts down to the next rush and starts it. True if one started.
func _update_rush_countdown(delta: float) -> bool:
	if _last_seen.size() < Tuning.group_rush_min:
		_next_rush = -1.0 # Starts again when there's a pack
		return false
	if _next_rush < 0:
		_next_rush = randf_range(Tuning.group_rush_interval_min,
			maxf(Tuning.group_rush_interval_min, Tuning.group_rush_interval_max))
	_next_rush -= delta
	if _next_rush > 0 || _anyone_swinging():
		return false
	_next_rush = -1.0
	return _start_rush()

func _anyone_swinging() -> bool:
	for enemy in _last_seen:
		if _alive(enemy) && enemy.is_swinging():
			return true
	return false

func _start_rush() -> bool:
	var player_at: Vector2 = Game.player.global_position
	var candidates: Array[Enemy] = []
	for enemy in _last_seen:
		if _alive(enemy) && enemy.can_take_turn() && enemy.has_method("begin_group_rush"):
			candidates.append(enemy)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(player_at) < b.global_position.distance_squared_to(player_at))
	var free_sides: Array = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var sides := {}
	for enemy in candidates:
		if sides.size() >= Tuning.group_rush_max:
			break
		var side: Vector2 = enemy.pick_rush_side(free_sides)
		if side != Vector2.ZERO:
			free_sides.erase(side)
			sides[enemy] = side
	if sides.size() < Tuning.group_rush_min:
		return false
	_attackers.clear()
	_turn_time.clear()
	for enemy: Enemy in sides:
		enemy.begin_group_rush(sides[enemy])
		_rushers.append(enemy)
	_rush_time = 0.0
	_rush_launched = false
	return true

func _update_rush(delta: float) -> void:
	for enemy in _rushers.duplicate():
		if !_alive(enemy) || !_last_seen.has(enemy) || enemy.is_stunned():
			if _alive(enemy):
				enemy.end_group_rush()
			_rushers.erase(enemy)
	if _rushers.is_empty():
		_end_rush()
		return
	_rush_time += delta
	if !_rush_launched:
		var all_ready := true
		for enemy in _rushers:
			if !enemy.is_rush_ready():
				all_ready = false
		if all_ready || _rush_time >= Tuning.group_rush_gather_time:
			for enemy in _rushers.duplicate():
				if enemy.is_rush_ready():
					enemy.rush_strike()
				else:
					enemy.end_group_rush()
					_rushers.erase(enemy)
			_rush_launched = true
		return
	for enemy in _rushers:
		if enemy.is_rush_striking():
			return
	_end_rush()

func _end_rush() -> void:
	for enemy in _rushers:
		if _alive(enemy):
			enemy.end_group_rush()
	_rushers.clear()
	_rush_launched = false
	_next_rush = -1.0
	_gap = randf_range(Tuning.pack_turn_gap_min, maxf(Tuning.pack_turn_gap_min, Tuning.pack_turn_gap_max))
