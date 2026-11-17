class_name RoomDesign
extends RefCounted

# A room drawn in the room creator: what is on each cell of a 13x13 floor, plus the
# enemies and switches standing on it. It can paint itself onto a room's tile layers (the
# editor's preview), build a playable Room (the play-test), and write itself out as text
# (the export, for adding the room to the game).
#
# Cells here are floor indices, (0, 0) to (SIZE - 1, SIZE - 1), top-left first. tile_cell()
# turns one into the TileMap cell it covers.

enum Cell { FLOOR, PIT, STALAGMITE }

const SIZE := Room.STANDARD_FLOOR_SIZE
const BLANK_ROOM := "res://src/editor/BlankRoom.tscn"
const SWITCHES_SCRIPT := "res://src/objects/Switches.gd"
const OBJECT_SCENES := {
	"goblin": "res://src/enemies/Goblin.tscn",
	"knight": "res://src/enemies/Knight.tscn",
	"wizard": "res://src/enemies/Wizard.tscn",
	"switch": "res://src/objects/Switch.tscn",
}
const ENEMY_FEET := Vector2(0, 8) # Enemies stand this far below their origin (Enemy.FEET_OFFSET)
const SWITCH_CENTRE := Vector2(324, 322) # Switch.tscn draws its art here, relative to its origin

# Characters in the exported grid.
const CELL_CHARS := {Cell.FLOOR: ".", Cell.PIT: "#", Cell.STALAGMITE: "S"}
const OBJECT_CHARS := {"goblin": "G", "knight": "K", "wizard": "W", "switch": "O"}
# Enemies with a detection radius (MeleeEnemy.detection_radius). Wizards engage anywhere
# in the room, so they have none.
const DETECTING_KINDS: Array[String] = ["goblin", "knight"]
const RADIUS_MIN := 0.0
const RADIUS_MAX := 400.0

const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# The design open in the room creator. Kept here so it survives the trip to the
# play-test and back.
static var current: RoomDesign

var cells := PackedByteArray() # Cell per floor index, row by row
var objects := {} # Vector2i floor index -> object kind (a key of OBJECT_SCENES)
# Vector2i floor index -> detection radius in pixels, for goblins and knights given one
# other than MeleeEnemy.DEFAULT_DETECTION_RADIUS.
var radii := {}
var clear_by := "none" # What opens the room's doors: "none" (never locked), "enemies" or "switches"
var floors := Room.ALL_FLOORS # Room.floors: bit n - 1 set if it can appear on floor n
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

# Sets the ground on `index`. Anything but floor knocks off an object standing there.
func set_cell(index: Vector2i, kind: Cell) -> void:
	cells[index.y * SIZE + index.x] = kind
	if kind != Cell.FLOOR:
		objects.erase(index)
		radii.erase(index)

# Puts an object on `index`, clearing the ground under it to floor. Putting the same kind
# back on itself keeps its detection radius.
func set_object(index: Vector2i, kind: String) -> void:
	cells[index.y * SIZE + index.x] = Cell.FLOOR
	if objects.get(index) != kind:
		radii.erase(index)
	objects[index] = kind

static func has_radius(kind: String) -> bool:
	return kind in DETECTING_KINDS

# Detection radius of the goblin or knight on `index`.
func radius_at(index: Vector2i) -> float:
	return radii.get(index, MeleeEnemy.DEFAULT_DETECTION_RADIUS)

# Whole pixels; the default isn't stored, so it doesn't show up in the export.
func set_radius(index: Vector2i, radius: float) -> void:
	radius = clampf(roundf(radius), RADIUS_MIN, RADIUS_MAX)
	if radius == MeleeEnemy.DEFAULT_DETECTION_RADIUS:
		radii.erase(index)
	else:
		radii[index] = radius

# Removes the object on `index` if there is one, otherwise turns the cell back to floor.
func erase(index: Vector2i) -> void:
	if objects.has(index):
		objects.erase(index)
		radii.erase(index)
	else:
		set_cell(index, Cell.FLOOR)

func clear() -> void:
	cells.fill(Cell.FLOOR)
	objects.clear()
	radii.clear()

# Removes every goblin, knight and wizard; switches stay.
func clear_enemies() -> void:
	for index: Vector2i in objects.keys():
		if objects[index] != "switch":
			objects.erase(index)
			radii.erase(index)

# Turns every pitfall and stalagmite back to floor; enemies and switches stay.
func clear_tiles() -> void:
	cells.fill(Cell.FLOOR)

# --- Undo and redo ---
# Each step is a snapshot of the whole design from before the change. The room is tiny
# (169 cells), so whole copies are simpler than recording individual edits.

const HISTORY_LIMIT := 200

var _undo_steps: Array[Dictionary] = []
var _redo_steps: Array[Dictionary] = []

func snapshot() -> Dictionary:
	return {"cells": cells.duplicate(), "objects": objects.duplicate(), "radii": radii.duplicate(),
		"clear_by": clear_by, "floors": floors}

func restore(state: Dictionary) -> void:
	cells = (state.cells as PackedByteArray).duplicate()
	objects = (state.objects as Dictionary).duplicate()
	radii = (state.radii as Dictionary).duplicate()
	floors = state.floors
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

func enemy_count() -> int:
	return objects.size() - count("switch")

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
	return ""

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

# Draws every cell onto `room`'s Tiles, Pitfalls and Stalagmites layers.
func paint_all(room: Node) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			paint(room, Vector2i(x, y))

# Draws `index` onto `room`, and rejoins the stalagmites round it.
func paint(room: Node, index: Vector2i) -> void:
	var tile := tile_cell(index)
	var tiles: TileMap = room.get_node("Tiles")
	var pitfalls: TileMap = room.get_node("Pitfalls")
	var kind := get_cell(index)
	# Rooms have no floor tile under a pit.
	if kind == Cell.PIT:
		tiles.erase_cell(0, tile)
		pitfalls.set_cell(0, tile, 0, Vector2i.ZERO)
	else:
		tiles.set_cell(0, tile, Room.FLOOR, Vector2i.ZERO)
		pitfalls.erase_cell(0, tile)
	var stalagmites: TileMap = room.get_node("Stalagmites")
	_paint_stalagmite(stalagmites, index)
	for step in NEIGHBOURS:
		_paint_stalagmite(stalagmites, index + step)

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
		if kind == "switch":
			switches.add_child(node, true)
		else:
			room.add_child(node, true)
	room.completion_criteria = completion()
	room.enemy_count = enemy_count()
	room.floors = floors
	return room

# --- Export ---

func to_text() -> String:
	var lines: PackedStringArray = [
		"# Infinite Labyrinth room design, made with the room creator.",
		"# Give this file to Claude to add the room to src/world/rooms/.",
		"version: 2",
		"floor_size: %d" % SIZE,
		"completion: %s" % completion(),
		"enemy_count: %d" % enemy_count(),
		"# Floors the room can appear on (Room.floors, 1-10; later floors follow floor 10):",
		"floors: %s" % ",".join(PackedStringArray(floor_list().map(func(n: int) -> String: return str(n)))),
		"# One character per floor cell, top row first (cell 0,0 is the top-left floor tile):",
		"#   .  floor    #  pitfall    S  stalagmite (joins its stalagmite neighbours)",
		"#   G  goblin   K  knight     W  wizard     O  switch",
		"# Goblins, knights, wizards and switches stand on floor.",
		"grid:",
	]
	for y in range(SIZE):
		var row := ""
		for x in range(SIZE):
			var index := Vector2i(x, y)
			row += OBJECT_CHARS[objects[index]] if objects.has(index) else CELL_CHARS[get_cell(index)]
		lines.append(row)
	lines.append("# Detection radius in pixels of each goblin and knight (MeleeEnemy.detection_radius),")
	lines.append("# by floor cell as column,row. Any not listed use the default, %d."
		% MeleeEnemy.DEFAULT_DETECTION_RADIUS)
	lines.append("detection_radius:")
	var listed: Array = radii.keys()
	listed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y || (a.y == b.y && a.x < b.x))
	for index: Vector2i in listed:
		lines.append("%d,%d %d" % [index.x, index.y, radii[index]])
	return "\n".join(lines) + "\n"
