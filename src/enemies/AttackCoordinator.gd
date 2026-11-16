class_name AttackCoordinator
extends Node

# Takes turns for a room's melee enemies so the player only has one attacker to read and
# parry at a time. Every melee enemy fighting the player checks in each physics frame; the
# coordinator hands one of them (Tuning.pack_max_attackers) the turn to step in and swing,
# and the rest circle at a distance. When a turn ends there's a random gap, then a random
# enemy (preferably not the one that just went) gets the next.
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
