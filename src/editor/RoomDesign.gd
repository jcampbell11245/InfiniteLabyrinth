class_name RoomDesign
extends RefCounted

# A room drawn in the room creator: what is on each cell of a 13x13 floor, plus the
# enemies and switches standing on it. It can paint itself onto a room's tile layers (the
# editor's preview), build a playable Room (the play-test), and write itself out as text
# (the export, for adding the room to the game).
#
# Cells here are floor indices, (0, 0) to (SIZE - 1, SIZE - 1), top-left first. tile_cell()
# turns one into the TileMap cell it covers.

# FLOOR to STALAGMITE and INNER_WALL are drawn on the room's own tile layers; the rest are
# special tiles, drawn on its SpecialTiles layer over plain floor (see SpecialTiles for what
# each does). INNER_WALL comes last so the values of the others don't change.
enum Cell {
	FLOOR, PIT, STALAGMITE,
	WIRES, SPIKES, CRACKED, SLICK, PLATE, PASTE, SLOW, FAST,
	TELEPORT_1, TELEPORT_2, TELEPORT_3, TELEPORT_4,
	INNER_WALL,
}
# The SpecialTiles frame each special cell is painted with.
const SPECIAL_FRAMES := {
	Cell.WIRES: SpecialTiles.Frame.WIRES,
	Cell.SPIKES: SpecialTiles.Frame.SPIKES,
	Cell.CRACKED: SpecialTiles.Frame.CRACKED,
	Cell.SLICK: SpecialTiles.Frame.SLICK,
	Cell.PLATE: SpecialTiles.Frame.PLATE,
	Cell.PASTE: SpecialTiles.Frame.PASTE,
	Cell.SLOW: SpecialTiles.Frame.SLOW,
	Cell.FAST: SpecialTiles.Frame.FAST,
	Cell.TELEPORT_1: SpecialTiles.Frame.TELEPORT_1,
	Cell.TELEPORT_2: SpecialTiles.Frame.TELEPORT_2,
	Cell.TELEPORT_3: SpecialTiles.Frame.TELEPORT_3,
	Cell.TELEPORT_4: SpecialTiles.Frame.TELEPORT_4,
}
const TELEPORTS: Array[Cell] = [Cell.TELEPORT_1, Cell.TELEPORT_2, Cell.TELEPORT_3, Cell.TELEPORT_4]
const TELEPORT_NAMES: Array[String] = ["red dot", "blue triangle", "green square", "yellow diamond"]

const SIZE := Room.STANDARD_FLOOR_SIZE
const BLANK_ROOM := "res://src/editor/BlankRoom.tscn"
const SWITCHES_SCRIPT := "res://src/objects/Switches.gd"
const OBJECT_SCENES := {
	"goblin": "res://src/enemies/Goblin.tscn",
	"knight": "res://src/enemies/Knight.tscn",
	"troll": "res://src/enemies/Troll.tscn",
	"orc": "res://src/enemies/Orc.tscn",
	"hobgoblin": "res://src/enemies/Hobgoblin.tscn",
	"pilot": "res://src/enemies/Pilot.tscn",
	"dual_knight": "res://src/enemies/DualKnight.tscn",
	"warlock": "res://src/enemies/Warlock.tscn",
	"necromancer": "res://src/enemies/Necromancer.tscn",
	"wizard": "res://src/enemies/Wizard.tscn",
	"wyrm": "res://src/enemies/Wyrm.tscn",
	"wyvern": "res://src/enemies/Wyvern.tscn",
	"centaur": "res://src/enemies/Centaur.tscn",
	"bucentaur": "res://src/enemies/Bucentaur.tscn",
	"taurtaur": "res://src/enemies/Taurtaur.tscn",
	"server": "res://src/enemies/Server.tscn",
	"switch": "res://src/objects/Switch.tscn",
}
const ENEMY_FEET := Vector2(0, 8) # Enemies stand this far below their origin (Enemy.FEET_OFFSET)
const SWITCH_CENTRE := Vector2(324, 322) # Switch.tscn draws its art here, relative to its origin

# Characters in the exported grid.
const CELL_CHARS := {
	Cell.FLOOR: ".", Cell.PIT: "#", Cell.STALAGMITE: "S", Cell.INNER_WALL: "X",
	Cell.WIRES: "E", Cell.SPIKES: "^", Cell.CRACKED: "%", Cell.SLICK: "=", Cell.PLATE: "P",
	Cell.PASTE: "&", Cell.SLOW: "-", Cell.FAST: "+",
	Cell.TELEPORT_1: "1", Cell.TELEPORT_2: "2", Cell.TELEPORT_3: "3", Cell.TELEPORT_4: "4",
}
const OBJECT_CHARS := {"goblin": "G", "knight": "K", "wizard": "W", "switch": "O", "troll": "T", "orc": "R", "dual_knight": "D", "warlock": "L", "necromancer": "N", "wyrm": "Y", "wyvern": "V", "centaur": "C", "bucentaur": "B", "taurtaur": "U", "server": "Z", "hobgoblin": "H", "pilot": "I"}
# Enemies with a detection radius (MeleeEnemy.detection_radius, Wyrm.detection_radius), which
# also set which way they face at the start. Wizards engage anywhere in the room, so they
# have none.
const DETECTING_KINDS: Array[String] = ["goblin", "knight", "troll", "orc", "hobgoblin", "pilot", "dual_knight", "wyrm", "wyvern",
	"centaur", "bucentaur", "taurtaur"]
# Of those, the ones that can roam (MeleeEnemy.roam_mode): not the dragons, which hover.
const ROAMING_KINDS: Array[String] = ["goblin", "knight", "troll", "orc", "hobgoblin", "pilot", "dual_knight", "centaur",
	"bucentaur", "taurtaur"]
# Enemies a goblin pilot can ride (Enemy.mountable), which get the Pilot switch.
const MOUNT_KINDS: Array[String] = ["orc", "wyrm", "wyvern", "centaur", "bucentaur", "taurtaur"]
const RADIUS_MIN := 0.0
const RADIUS_MAX := 400.0
# Roaming (MeleeEnemy.roam_mode), for ROAMING_KINDS: "none", "path" or "area".
const ROAM_MODES: Array[String] = ["none", "path", "area"]
const AREA_DEFAULT_REACH := 2 # Cells either side of the enemy a new roaming area covers
# Spawn facing (MeleeEnemy.starting_direction), for the same kinds: a direction, or "auto" to
# turn to the player as they come into the room. Right, the scenes' own, isn't stored.
const FACINGS: Array[String] = [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT, MeleeEnemy.AUTO_FACING]
const DEFAULT_FACING := Direction.RIGHT
# Servers (see Server): the circle a new one covers, in pixels (5 cells), and what it boosts.
const SERVER_DEFAULT_RADIUS := 120.0
const SERVER_DEFAULTS := {"buff": ServerBuff.RANDOM, "pool": ["attack", "defense", "speed"], "whole_room": false}

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# The design open in the room creator. Kept here so it survives the trip to the
# play-test and back.
static var current: RoomDesign

var cells := PackedByteArray() # Cell per floor index, row by row
var objects := {} # Vector2i floor index -> object kind (a key of OBJECT_SCENES)
# Vector2i floor index -> detection radius in pixels, for goblins and knights given one
# other than MeleeEnemy.DEFAULT_DETECTION_RADIUS.
var radii := {}
# Vector2i floor index -> how the goblin or knight there roams, if it does:
# {"mode": "path", "points": Array of Vector2i}, the cells it walks through after its own
# and back again; or {"mode": "area", "rect": Rect2i}, the cells it wanders in (always
# including its own).
var roams := {}
# Vector2i floor index -> spawn facing (one of FACINGS) of goblins and knights not facing
# DEFAULT_FACING.
var facings := {}
# Vector2i floor index -> true, for each mount that starts the room with a pilot on it
# (Enemy.spawn_with_pilot). Pilots made this way are extra enemies, counted by the room as
# they appear rather than in enemy_count.
var pilots := {}
# Vector2i floor index -> what the server there does: {"buff": one of ServerBuff.SETTINGS,
# "pool": the kinds "random" and "random_swap" pick from, "whole_room": bool}. Its circle's
# radius is in `radii`, like a detection radius.
var servers := {}
var clear_by := "none" # What opens the room's doors: "none" (never locked), "enemies" or "switches"
var floors := Room.ALL_FLOORS # Room.floors: bit n - 1 set if it can appear on floor n
var brightness := 1.0 # Room.brightness: times the cave's brightness while in the room
# Which floor's tileset the room creator and its play-test draw with. Only for looking at;
# not part of the design, so it isn't undone or exported.
var preview_floor := 1

func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(Cell.FLOOR)

static func tile_cell(index: Vector2i) -> Vector2i:
	return index + Vector2i.ONE * Room.FLOOR_FIRST

static func floor_index(tile: Vector2i) -> Vector2i:
	return tile - Vector2i.ONE * Room.FLOOR_FIRST

static func in_floor(index: Vector2i) -> bool:
	return index.x >= 0 && index.y >= 0 && index.x < SIZE && index.y < SIZE

# Room-local origin for an object of `kind` standing on `index`.
static func object_origin(kind: String, index: Vector2i) -> Vector2:
	var centre := (Vector2(tile_cell(index)) + Vector2(0.5, 0.5)) * Room.CELL_SIZE
	if kind == "switch":
		return centre - SWITCH_CENTRE
	return centre - ENEMY_FEET

func get_cell(index: Vector2i) -> Cell:
	return cells[index.y * SIZE + index.x] as Cell

static func is_special(kind: Cell) -> bool:
	return SPECIAL_FRAMES.has(kind)

# Ground something can walk on: floor and every special tile, but not a pit, rock or wall.
static func is_walkable(kind: Cell) -> bool:
	return kind != Cell.PIT && kind != Cell.STALAGMITE && kind != Cell.INNER_WALL

# Sets the ground on `index`. Anything but floor knocks off an object standing there.
func set_cell(index: Vector2i, kind: Cell) -> void:
	cells[index.y * SIZE + index.x] = kind
	if kind != Cell.FLOOR:
		_forget(index)
	if !is_walkable(kind):
		# Paths can't run through a pit or rock (they can cross special tiles).
		for enemy: Vector2i in roams:
			if roams[enemy].mode == "path" && (roams[enemy].points as Array).has(index):
				(roams[enemy].points as Array).erase(index)
				simplify_path(enemy)

# Puts an object on `index`, clearing the ground under it to floor. Putting the same kind
# back on itself keeps its detection radius.
func set_object(index: Vector2i, kind: String) -> void:
	cells[index.y * SIZE + index.x] = Cell.FLOOR
	if objects.get(index) != kind:
		radii.erase(index)
		roams.erase(index)
		facings.erase(index)
		pilots.erase(index)
		servers.erase(index)
		if kind == "server":
			servers[index] = SERVER_DEFAULTS.duplicate(true)
	objects[index] = kind

# Removes the object on `index` and everything set for it.
func _forget(index: Vector2i) -> void:
	objects.erase(index)
	radii.erase(index)
	roams.erase(index)
	facings.erase(index)
	pilots.erase(index)
	servers.erase(index)

# Has a detection radius (goblins, knights, dragons, centaurs).
static func has_radius(kind: String) -> bool:
	return kind in DETECTING_KINDS

# Has a circle drawn round it in the room creator that can be dragged: a detection radius,
# or the area a server covers.
static func has_circle(kind: String) -> bool:
	return has_radius(kind) || kind == "server"

# The radius of an object of `kind` that hasn't been given one.
static func default_radius(kind: String) -> float:
	return SERVER_DEFAULT_RADIUS if kind == "server" else float(MeleeEnemy.DEFAULT_DETECTION_RADIUS)

# Detection radius of the goblin or knight on `index`, or the circle the server there covers.
func radius_at(index: Vector2i) -> float:
	return radii.get(index, default_radius(objects.get(index, "")))

# Whole pixels; the default isn't stored, so it doesn't show up in the export.
func set_radius(index: Vector2i, radius: float) -> void:
	radius = clampf(roundf(radius), RADIUS_MIN, RADIUS_MAX)
	if radius == default_radius(objects.get(index, "")):
		radii.erase(index)
	else:
		radii[index] = radius

# Removes the object on `index` if there is one, otherwise turns the cell back to floor.
func erase(index: Vector2i) -> void:
	if objects.has(index):
		_forget(index)
	else:
		set_cell(index, Cell.FLOOR)

func clear() -> void:
	cells.fill(Cell.FLOOR)
	objects.clear()
	radii.clear()
	roams.clear()
	facings.clear()
	pilots.clear()
	servers.clear()

# Removes every enemy and server; switches stay.
func clear_enemies() -> void:
	for index: Vector2i in objects.keys():
		if objects[index] != "switch":
			_forget(index)

# Turns every pitfall, stalagmite, inner wall and special tile back to floor; enemies and switches stay.
func clear_tiles() -> void:
	cells.fill(Cell.FLOOR)

# --- Facing ---

static func can_face(kind: String) -> bool:
	return has_radius(kind)

# Which way the goblin or knight on `index` faces when the room starts (one of FACINGS).
func facing_at(index: Vector2i) -> String:
	return facings.get(index, DEFAULT_FACING)

func set_facing(index: Vector2i, facing: String) -> void:
	if !objects.has(index) || !can_face(objects[index]) || !(facing in FACINGS):
		return
	if facing == DEFAULT_FACING:
		facings.erase(index)
	else:
		facings[index] = facing

# --- Pilots ---

static func can_carry_pilot(kind: String) -> bool:
	return kind in MOUNT_KINDS

func has_pilot(index: Vector2i) -> bool:
	return pilots.has(index)

# Puts a pilot on (or takes it off) the mount on `index`, if there is one.
func set_pilot(index: Vector2i, on: bool) -> void:
	if !on:
		pilots.erase(index)
	elif objects.has(index) && can_carry_pilot(objects[index]):
		pilots[index] = true
# --- Servers ---

# What the server on `index` does (see `servers`), or {} if there's no server there.
func server_at(index: Vector2i) -> Dictionary:
	return servers.get(index, {})

# Sets what the server on `index` boosts: one of ServerBuff.SETTINGS.
func set_server_buff(index: Vector2i, buff: String) -> void:
	if servers.has(index) && buff in ServerBuff.SETTINGS:
		servers[index].buff = buff

# Puts kind `name` ("attack", "defense" or "speed") in or out of the pool the server on
# `index` picks from when random. The last one can't be taken out.
func set_server_pool(index: Vector2i, name: String, on: bool) -> void:
	if !servers.has(index) || ServerBuff.kind_named(name) < 0:
		return
	var pool: Array = servers[index].pool
	if on && !pool.has(name):
		pool.append(name)
		# Kept in the usual order, so the export doesn't depend on the order of clicks.
		pool.sort_custom(func(a: String, b: String) -> bool:
			return ServerBuff.kind_named(a) < ServerBuff.kind_named(b))
	elif !on && pool.has(name) && pool.size() > 1:
		pool.erase(name)

# Makes the server on `index` cover its whole room, or just its circle.
func set_server_whole_room(index: Vector2i, whole_room: bool) -> void:
	if servers.has(index):
		servers[index].whole_room = whole_room

# --- Roaming ---

static func can_roam(kind: String) -> bool:
	return kind in ROAMING_KINDS

# "none", "path" or "area" for the enemy on `index`.
func roam_mode(index: Vector2i) -> String:
	return roams[index].mode if roams.has(index) else "none"

# Switches the enemy on `index` to roaming `mode`, starting it afresh: an empty path, or an
# area AREA_DEFAULT_REACH cells round it. Picking the mode it already has changes nothing.
func set_roam_mode(index: Vector2i, mode: String) -> void:
	if mode == roam_mode(index) || !objects.has(index) || !can_roam(objects[index]):
		return
	match mode:
		"path":
			roams[index] = {"mode": "path", "points": []}
		"area":
			roams[index] = {"mode": "area", "rect": Rect2i()}
			var reach := Vector2i.ONE * AREA_DEFAULT_REACH
			set_area(index, Rect2i(index - reach, reach * 2 + Vector2i.ONE))
		_:
			roams.erase(index)

# The cells the enemy on `index` walks through after its own, or [] if it has no path.
func path_points(index: Vector2i) -> Array:
	return roams[index].points if roam_mode(index) == "path" else []

# Adds `cell` to the end of the path of the enemy on `index`. Going back onto the point
# before the last takes the last one off instead, so a drag can back up. False if nothing
# changed (not floor, or already the end).
func add_path_point(index: Vector2i, cell: Vector2i) -> bool:
	if roam_mode(index) != "path" || !in_floor(cell) || !is_walkable(get_cell(cell)):
		return false
	var points: Array = roams[index].points
	var last: Vector2i = points.back() if !points.is_empty() else index
	if cell == last:
		return false
	var before_last: Vector2i = points[-2] if points.size() >= 2 else index
	if !points.is_empty() && cell == before_last:
		points.pop_back()
	else:
		points.append(cell)
	return true

# Takes `cell` out of the path of the enemy on `index`. False if it wasn't on it.
func remove_path_point(index: Vector2i, cell: Vector2i) -> bool:
	var points := path_points(index)
	if !points.has(cell):
		return false
	points.erase(cell)
	simplify_path(index)
	return true

# Drops points that change nothing about the walk: the same cell twice in a row, and points
# partway along a straight stretch.
func simplify_path(index: Vector2i) -> void:
	if roam_mode(index) != "path":
		return
	var points: Array = roams[index].points
	var i := 0
	while i < points.size():
		var previous: Vector2i = points[i - 1] if i > 0 else index
		if previous == points[i]:
			points.remove_at(i)
			continue
		if i + 1 < points.size():
			var into := Vector2(points[i] - previous)
			var out := Vector2(points[i + 1] - points[i])
			if is_zero_approx(into.cross(out)) && into.dot(out) > 0:
				points.remove_at(i)
				continue
		i += 1

# The cells the enemy on `index` wanders in, or an empty rect if it has no area.
func area_rect(index: Vector2i) -> Rect2i:
	return roams[index].rect if roam_mode(index) == "area" else Rect2i()

# Sets the area of the enemy on `index`, kept on the floor and round the enemy's own cell.
func set_area(index: Vector2i, rect: Rect2i) -> void:
	if roam_mode(index) != "area":
		return
	var left := clampi(rect.position.x, 0, index.x)
	var top := clampi(rect.position.y, 0, index.y)
	var right := clampi(rect.end.x - 1, index.x, SIZE - 1)
	var bottom := clampi(rect.end.y - 1, index.y, SIZE - 1)
	roams[index].rect = Rect2i(left, top, right - left + 1, bottom - top + 1)

# Room-local pixels a rect of floor cells covers.
static func area_pixels(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(tile_cell(rect.position)) * Room.CELL_SIZE, Vector2(rect.size) * Room.CELL_SIZE)

# Room-local middle of floor cell `index`, where an enemy standing on it has its feet.
static func cell_centre(index: Vector2i) -> Vector2:
	return (Vector2(tile_cell(index)) + Vector2(0.5, 0.5)) * Room.CELL_SIZE

# --- Undo and redo ---
# Each step is a snapshot of the whole design from before the change. The room is tiny
# (169 cells), so whole copies are simpler than recording individual edits.

const HISTORY_LIMIT := 200

var _undo_steps: Array[Dictionary] = []
var _redo_steps: Array[Dictionary] = []

func snapshot() -> Dictionary:
	return {"cells": cells.duplicate(), "objects": objects.duplicate(), "radii": radii.duplicate(),
		"roams": roams.duplicate(true), "facings": facings.duplicate(), "pilots": pilots.duplicate(),
		"servers": servers.duplicate(true), "clear_by": clear_by, "floors": floors, "brightness": brightness}

func restore(state: Dictionary) -> void:
	cells = (state.cells as PackedByteArray).duplicate()
	objects = (state.objects as Dictionary).duplicate()
	radii = (state.radii as Dictionary).duplicate()
	roams = (state.roams as Dictionary).duplicate(true)
	facings = (state.get("facings", {}) as Dictionary).duplicate()
	pilots = (state.get("pilots", {}) as Dictionary).duplicate()
	servers = (state.get("servers", {}) as Dictionary).duplicate(true)
	floors = state.floors
	brightness = state.get("brightness", 1.0)
	clear_by = state.clear_by

# Records a change made since `before` (a snapshot()) as one undo step. Does nothing if
# the design ended up the same, so a click that changes nothing isn't a step.
func record(before: Dictionary) -> void:
	if before == snapshot():
		return
	_undo_steps.append(before)
	if _undo_steps.size() > HISTORY_LIMIT:
		_undo_steps.pop_front()
	_redo_steps.clear()

func can_undo() -> bool:
	return !_undo_steps.is_empty()

func can_redo() -> bool:
	return !_redo_steps.is_empty()

func undo() -> void:
	if can_undo():
		_redo_steps.append(snapshot())
		restore(_undo_steps.pop_back())

func redo() -> void:
	if can_redo():
		_undo_steps.append(snapshot())
		restore(_redo_steps.pop_back())

func count(kind: String) -> int:
	return objects.values().count(kind)

# Enemies that have to be beaten to clear the room: not switches, nor servers (see Server).
func enemy_count() -> int:
	return objects.size() - count("switch") - count("server")

# What opens the room, as Room.completion_criteria: beating its enemies, hitting its
# switches, or nothing ("none": the doors never lock).
func completion() -> String:
	return clear_by

# The floors the room can appear on, in words: "Every floor", "Floor 1", "Floors 1-3, 5".
func floors_text() -> String:
	var ticked := floor_list()
	if ticked.size() == Room.FLOOR_CHOICES:
		return "Every floor"
	if ticked.is_empty():
		return "No floors"
	# Runs of floors in a row read as ranges: 1-3, 5.
	var parts: PackedStringArray = []
	var start: int = ticked[0]
	for i in range(1, ticked.size() + 1):
		if i == ticked.size() || ticked[i] != ticked[i - 1] + 1:
			var last: int = ticked[i - 1]
			parts.append(str(start) if last == start else "%d-%d" % [start, last])
			if i < ticked.size():
				start = ticked[i]
	return ("Floor " if ticked.size() == 1 else "Floors ") + ", ".join(parts)

# The ticked floors, lowest first.
func floor_list() -> Array[int]:
	var ticked: Array[int] = []
	for n in range(1, Room.FLOOR_CHOICES + 1):
		if Room.allowed_on(n, floors):
			ticked.append(n)
	return ticked

func set_floor(floor_number: int, on: bool) -> void:
	var bit := 1 << (floor_number - 1)
	floors = (floors | bit) if on else (floors & ~bit)

# Why the room would open the moment the player walks in, or "" if it wouldn't.
func clear_problem() -> String:
	if clear_by == "switches" && count("switch") == 0:
		return "No switches: the room opens straight away"
	if clear_by == "enemies" && enemy_count() == 0:
		return "No enemies: the room opens straight away"
	if floors == 0:
		return "No floors ticked: the room never appears"
	for i in TELEPORTS.size():
		if cell_count(TELEPORTS[i]) == 1:
			return "The %s teleporter needs a second square to send things to" % TELEPORT_NAMES[i]
	return ""

func cell_count(kind: Cell) -> int:
	return Array(cells).count(kind)

# Where the play-test puts the player: the free floor cell nearest the middle of the left
# edge, just inside the left door, as if they had walked in from the room to the left.
func spawn_index() -> Vector2i:
	@warning_ignore("integer_division")
	var target := Vector2i(0, SIZE / 2)
	var best := target
	var best_distance := INF
	for y in range(SIZE):
		for x in range(SIZE):
			var index := Vector2i(x, y)
			var distance := Vector2(index - target).length()
			if get_cell(index) == Cell.FLOOR && !objects.has(index) && distance < best_distance:
				best = index
				best_distance = distance
	return best

# --- Drawing onto a room ---

# Draws every cell onto `room`'s Tiles, Pitfalls, Stalagmites, InnerWalls and SpecialTiles layers.
func paint_all(room: Node) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			paint(room, Vector2i(x, y))

# Draws `index` onto `room`, and rejoins the stalagmites and inner walls round it (inner
# walls join diagonally too).
func paint(room: Node, index: Vector2i) -> void:
	var tile := tile_cell(index)
	var tiles: TileMap = room.get_node("Tiles")
	var pitfalls: TileMap = room.get_node("Pitfalls")
	var kind := get_cell(index)
	# Special tiles sit on plain floor, on a layer of their own made the first time one is painted.
	var special := room.get_node_or_null(SpecialTiles.NODE_NAME) as SpecialTiles
	if is_special(kind):
		special = SpecialTiles.of(room)
		special.set_cell(0, tile, 0, Vector2i(SPECIAL_FRAMES[kind], 0))
	elif special != null:
		special.erase_cell(0, tile)
	# Rooms have no floor tile under a pit.
	if kind == Cell.PIT:
		tiles.erase_cell(0, tile)
		pitfalls.set_cell(0, tile, 0, Vector2i.ZERO)
	else:
		tiles.set_cell(0, tile, Room.FLOOR, Vector2i.ZERO)
		pitfalls.erase_cell(0, tile)
	var stalagmites: TileMap = room.get_node("Stalagmites")
	var walls: TileMap = room.get_node("InnerWalls")
	_paint_stalagmite(stalagmites, index)
	for step in NEIGHBOURS:
		_paint_stalagmite(stalagmites, index + step)
	for y in range(-1, 2):
		for x in range(-1, 2):
			_paint_inner_wall(walls, index + Vector2i(x, y))

func _is_stalagmite(index: Vector2i) -> bool:
	return in_floor(index) && get_cell(index) == Cell.STALAGMITE

func _paint_stalagmite(stalagmites: TileMap, index: Vector2i) -> void:
	if !in_floor(index):
		return
	if !_is_stalagmite(index):
		stalagmites.erase_cell(0, tile_cell(index))
		return
	var mask := 0
	for i in range(NEIGHBOURS.size()):
		if _is_stalagmite(index + NEIGHBOURS[i]):
			mask |= 1 << i
	stalagmites.set_cell(0, tile_cell(index), Room.STALAGMITE_SOURCES[mask], Vector2i.ZERO)

func _is_inner_wall(index: Vector2i) -> bool:
	return in_floor(index) && get_cell(index) == Cell.INNER_WALL

func _paint_inner_wall(walls: TileMap, index: Vector2i) -> void:
	if !in_floor(index):
		return
	if !_is_inner_wall(index):
		walls.erase_cell(0, tile_cell(index))
		return
	walls.set_cell(0, tile_cell(index), 0, InnerWalls.atlas_cell(index, _is_inner_wall))

# --- Play-test ---

# A playable Room of this design, not yet in the tree. Its doors are still open; the
# caller closes them once it's added.
func build_room() -> Room:
	var room: Room = (load(BLANK_ROOM) as PackedScene).instantiate()
	paint_all(room)
	# Every room gets a Switches node, even with none, since a switch room reads it.
	var switches := Node2D.new()
	switches.name = "Switches"
	switches.set_script(load(SWITCHES_SCRIPT))
	room.add_child(switches)
	for index: Vector2i in objects:
		var kind: String = objects[index]
		var node: Node2D = (load(OBJECT_SCENES[kind]) as PackedScene).instantiate()
		node.position = object_origin(kind, index)
		if has_radius(kind):
			node.set("detection_radius", radius_at(index))
		if can_face(kind):
			node.set("starting_direction", facing_at(index))
		if has_pilot(index):
			node.set("spawn_with_pilot", true)
		match roam_mode(index):
			"path":
				var path := PackedVector2Array()
				for cell: Vector2i in path_points(index):
					path.append(object_origin(kind, cell))
				node.set("roam_mode", MeleeEnemy.Roam.PATH)
				node.set("roam_path", path)
			"area":
				node.set("roam_mode", MeleeEnemy.Roam.AREA)
				node.set("roam_area", area_pixels(area_rect(index)))
		if kind == "server":
			var server := server_at(index)
			node.set("buff", server.buff)
			node.set("buff_pool", PackedStringArray(server.pool))
			node.set("whole_room", server.whole_room)
			node.set("radius", radius_at(index))
		if kind == "switch":
			switches.add_child(node, true)
		else:
			room.add_child(node, true)
	room.completion_criteria = completion()
	room.enemy_count = enemy_count()
	room.floors = floors
	room.brightness = brightness
	return room

# --- Export ---

func to_text() -> String:
	var lines: PackedStringArray = [
		"# Infinite Labyrinth room design, made with the room creator.",
		"# Give this file to Claude to add the room to src/world/rooms/.",
		"version: 7",
		"floor_size: %d" % SIZE,
		"completion: %s" % completion(),
		"enemy_count: %d" % enemy_count(),
		"# Floors the room can appear on (Room.floors, 1-10; later floors follow floor 10):",
		"floors: %s" % ",".join(PackedStringArray(floor_list().map(func(n: int) -> String: return str(n)))),
		"# How lit the room is, times the cave's brightness (Room.brightness; 1 is the usual cave):",
		"brightness: %.2f" % brightness,
		"# One character per floor cell, top row first (cell 0,0 is the top-left floor tile):",
		"#   .  floor    #  pitfall    S  stalagmite (joins its stalagmite neighbours)",
		"#   X  inner wall (InnerWalls layer; joins its inner wall neighbours)",
		"#   G  goblin   K  knight     W  wizard     O  switch",
		"#   T  troll    R  orc        (goblin family: Troll.tscn, Orc.tscn)",
		"#   D  dual knight             (knight family: DualKnight.tscn)",
		"#   L  warlock    N  necromancer  (wizard family: Warlock.tscn, Necromancer.tscn)",
		"#   Y  wyrm       V  wyvern       (dragons: Wyrm.tscn, Wyvern.tscn)",
		"#   C  centaur    B  bucentaur  U  taurtaur  (centaurs: Centaur.tscn, Bucentaur.tscn, Taurtaur.tscn)",
		"#   H  hobgoblin  I  pilot     (goblin family: Hobgoblin.tscn, Pilot.tscn)",
		"#   Z  server (Server.tscn; boosts the enemies round it, see servers: below)",
		"# Special tiles, on a SpecialTiles layer (src/world/tiles/SpecialTiles.tscn) over plain",
		"# floor, each the SpecialTiles.Frame of the same name as its atlas column:",
		"#   E  exposed wires   ^  spikes        %  cracked floor   =  slick",
		"#   P  pressure plate  &  thermal paste  -  slow tile      +  speed tile",
		"#   1-4  teleporters (1 red dot, 2 blue triangle, 3 green square, 4 yellow diamond);",
		"#        each sends to the next square with the same number, in reading order",
		"# Enemies and switches stand on floor.",
		"grid:",
	]
	for y in range(SIZE):
		var row := ""
		for x in range(SIZE):
			var index := Vector2i(x, y)
			row += OBJECT_CHARS[objects[index]] if objects.has(index) else CELL_CHARS[get_cell(index)]
		lines.append(row)
	lines.append("# Detection radius in pixels of each goblin, knight and dragon (MeleeEnemy.detection_radius),")
	lines.append("# by floor cell as column,row. Any not listed use the default, %d."
		% MeleeEnemy.DEFAULT_DETECTION_RADIUS)
	lines.append("detection_radius:")
	for index: Vector2i in _sorted(radii.keys()):
		if has_radius(objects.get(index, "")):
			lines.append("%d,%d %d" % [index.x, index.y, radii[index]])
	lines.append("# How each goblin and knight that roams does so (MeleeEnemy.roam_mode), by floor cell as")
	lines.append("# column,row. Any not listed stand still until they notice the player.")
	lines.append("#   path: walks from its own cell through each listed cell in turn, then back again.")
	lines.append("#         MeleeEnemy.roam_path holds where the enemy stands on each (RoomDesign.object_origin).")
	lines.append("#   area: wanders the cells from the first corner to the second, inclusive.")
	lines.append("#         MeleeEnemy.roam_area holds the pixels those cells cover (RoomDesign.area_pixels).")
	lines.append("# Which way each goblin, knight and dragon faces when the room starts (starting_direction),")
	lines.append("# by floor cell as column,row: up, down, left, right, or auto (turns to face the player as")
	lines.append("# they come into the room). Any not listed face %s." % DEFAULT_FACING)
	lines.append("facing:")
	for index: Vector2i in _sorted(facings.keys()):
		lines.append("%d,%d %s" % [index.x, index.y, facings[index]])
	lines.append("# Mounts (orcs, dragons, centaurs) that start the room with a goblin pilot riding them")
	lines.append("# (Enemy.spawn_with_pilot = true), by floor cell as column,row. Their pilots aren't in enemy_count:")
	lines.append("# the room counts them as they appear.")
	lines.append("pilot:")
	for index: Vector2i in _sorted(pilots.keys()):
		lines.append("%d,%d" % [index.x, index.y])
	lines.append("roaming:")
	for index: Vector2i in _sorted(roams.keys()):
		var words: PackedStringArray = ["%d,%d" % [index.x, index.y], roam_mode(index)]
		if roam_mode(index) == "path":
			for cell: Vector2i in path_points(index):
				words.append("%d,%d" % [cell.x, cell.y])
		else:
			var rect := area_rect(index)
			words.append("%d,%d" % [rect.position.x, rect.position.y])
			words.append("%d,%d" % [rect.end.x - 1, rect.end.y - 1])
		lines.append(" ".join(words))
	lines.append("# What each server boosts, by floor cell as column,row (Server.buff, buff_pool, whole_room,")
	lines.append("# radius): attack, defense, speed, random (one kind from its pool, picked as the room is")
	lines.append("# built) or random_swap (switches between its pool's kinds); then \"room\" if it covers the")
	lines.append("# whole room, or its circle's radius in pixels; then its pool, for random and random_swap.")
	lines.append("servers:")
	for index: Vector2i in _sorted(servers.keys()):
		var server := server_at(index)
		var words: PackedStringArray = ["%d,%d" % [index.x, index.y], server.buff,
			"room" if server.whole_room else "%d" % radius_at(index)]
		if server.buff in [ServerBuff.RANDOM, ServerBuff.RANDOM_SWAP]:
			words.append(",".join(PackedStringArray(server.pool)))
		lines.append(" ".join(words))
	return "\n".join(lines) + "\n"

# Floor indices, top row first, left to right.
static func _sorted(indices: Array) -> Array:
	indices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y || (a.y == b.y && a.x < b.x))
	return indices
