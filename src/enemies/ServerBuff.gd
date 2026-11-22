class_name ServerBuff
extends RefCounted

# The boosts servers (see Server) give the enemies round them, and how strongly each enemy
# has each one. Every enemy asks every frame (through a Watcher child, see Enemy), so a
# boost starts the moment an enemy walks into a server's area and ends the moment the server
# breaks or the enemy walks out.
#
# A strength is 0 (no boost), 1 (the full boost, inside a server's area) or
# Tuning.floor_server_strength (a premium server's share, anywhere else on the floor).
# Boosts of the same kind don't stack: the strongest wins. Different kinds combine.

enum Kind { ATTACK, DEFENSE, SPEED }
const KINDS: Array[Kind] = [Kind.ATTACK, Kind.DEFENSE, Kind.SPEED]
# How each kind is written in room scenes, room designs and the room creator.
const NAMES := {Kind.ATTACK: "attack", Kind.DEFENSE: "defense", Kind.SPEED: "speed"}
# A server's buff setting can also be one of these: a kind picked from its pool once, as the
# room is built, or one that keeps switching (every Tuning.server_swap_time).
const RANDOM := "random"
const RANDOM_SWAP := "random_swap"
const SETTINGS: Array[String] = ["attack", "defense", "speed", RANDOM, RANDOM_SWAP]

# Status bar colour of each kind, which also tints the server's area. Speed matches the
# speed tile's bar, since it's the same kind of boost.
const COLORS := {
	Kind.ATTACK: Color(1.0, 0.3, 0.25),
	Kind.DEFENSE: Color(0.35, 0.6, 1.0),
	Kind.SPEED: Player.FAST_TILE_BAR,
}
# A random swap server's area is always tinted this, whatever it's giving at the moment: a
# tint that flashed between colours every few seconds could be hard on players sensitive to
# flashing.
const SWAP_COLOR := Color(1.0, 0.45, 0.8)
const ICONS := {
	Kind.ATTACK: StatusBars.Icon.ATTACK_UP,
	Kind.DEFENSE: StatusBars.Icon.DEFENSE_UP,
	Kind.SPEED: StatusBars.Icon.FAST,
}

# The kind named `name` ("attack", "defense" or "speed"), or -1.
static func kind_named(name: String) -> int:
	for kind: Kind in NAMES:
		if NAMES[kind] == name:
			return kind
	return -1

# The stat multiplier for `kind` at `strength`: damage dealt for ATTACK, damage taken for
# DEFENSE, walk and attack speed for SPEED. A partial strength gives that share of the boost:
# half of a 1.5x attack boost is 1.25x.
static func multiplier(kind: Kind, strength: float) -> float:
	var full := 1.0
	match kind:
		Kind.ATTACK: full = Tuning.server_attack_multiplier
		Kind.DEFENSE: full = Tuning.server_defense_multiplier
		Kind.SPEED: full = Tuning.server_speed_multiplier
	return lerpf(1.0, full, clampf(strength, 0.0, 1.0))

# How strongly each kind boosts `enemy` right now, by Kind, from every server standing (the
# servers are looked up once for all three, since every enemy asks every frame). Servers
# don't boost each other.
static func strengths_on(enemy: Enemy) -> Array[float]:
	var best: Array[float] = [0.0, 0.0, 0.0]
	if enemy is Server:
		return best
	for node in enemy.get_tree().get_nodes_in_group(Server.GROUP):
		var server := node as Server
		if server != null && !server.is_queued_for_deletion():
			for kind: Kind in KINDS:
				best[kind] = maxf(best[kind], server.strength_on(enemy, kind))
	return best

# Chance each server on floor `floor_number` has of being a premium (silver) server.
static func floor_server_chance(floor_number: int) -> float:
	var chance := Tuning.floor_server_chance_first + Tuning.floor_server_chance_step * (floor_number - 1)
	return clampf(chance, 0.0, Tuning.floor_server_chance_max)

# Rolls every server on the floor for turning silver (see Server.make_floor_server). Returns the
# ones that did.
static func roll_floor_servers(tree: SceneTree, floor_number: int, rng: RandomNumberGenerator) -> Array[Server]:
	var premium: Array[Server] = []
	var chance := floor_server_chance(floor_number)
	for node in tree.get_nodes_in_group(Server.GROUP):
		var server := node as Server
		if server != null && rng.randf() < chance:
			server.make_floor_server()
			premium.append(server)
	return premium

# A child of every enemy that keeps its boosts up to date each frame (Enemy.refresh_buffs).
# It costs nothing on a floor with no servers once the enemy's boosts are back to 0.
class Watcher:
	extends Node

	func _process(_delta: float) -> void:
		var enemy := get_parent() as Enemy
		if enemy != null && (get_tree().has_group(Server.GROUP) || enemy.has_buffs()):
			enemy.refresh_buffs()
