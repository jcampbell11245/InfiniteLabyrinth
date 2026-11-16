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

# Stalagmite tile source for each set of joined stalagmite neighbours, as a mask of
# 1 top, 2 right, 4 bottom, 8 left. Matches the source order in Stalagmites.tscn.
const STALAGMITE_SOURCES := {
	0: 0, 4: 1, 8: 2, 12: 3, 10: 4, 14: 5, 2: 6, 1: 7,
	5: 8, 9: 9, 13: 10, 11: 11, 15: 12, 3: 13, 7: 14, 6: 15,
}
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# The design open in the room creator. Kept here so it survives the trip to the
# play-test and back.
static var current: RoomDesign

var cells := PackedByteArray() # Cell per floor index, row by row
var objects := {} # Vector2i floor index -> object kind (a key of OBJECT_SCENES)
var clear_by := "none" # What opens the room's doors: "none" (never locked), "enemies" or "switches"

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

# Puts an object on `index`, clearing the ground under it to floor.
func set_object(index: Vector2i, kind: String) -> void:
	cells[index.y * SIZE + index.x] = Cell.FLOOR
	objects[index] = kind

# Removes the object on `index` if there is one, otherwise turns the cell back to floor.
func erase(index: Vector2i) -> void:
	if objects.has(index):
		objects.erase(index)
	else:
		set_cell(index, Cell.FLOOR)

func clear() -> void:
	cells.fill(Cell.FLOOR)
	objects.clear()

func count(kind: String) -> int:
	return objects.values().count(kind)

func enemy_count() -> int:
	return objects.size() - count("switch")

# What opens the room, as Room.completion_criteria: beating its enemies, hitting its
# switches, or nothing ("none": the doors never lock).
func completion() -> String:
	return clear_by

# Why the room would open the moment the player walks in, or "" if it wouldn't.
func clear_problem() -> String:
	if clear_by == "switches" && count("switch") == 0:
		return "No switches: the room opens straight away"
	if clear_by == "enemies" && enemy_count() == 0:
		return "No enemies: the room opens straight away"
	return ""

# Where the play-test puts the player: the free floor cell nearest the middle.
func spawn_index() -> Vector2i:
	var middle := Vector2i.ONE * (SIZE / 2)
	var best := middle
	var best_distance := INF
	for y in range(SIZE):
		for x in range(SIZE):
			var index := Vector2i(x, y)
			var distance := Vector2(index - middle).length()
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
	stalagmites.set_cell(0, tile_cell(index), STALAGMITE_SOURCES[mask], Vector2i.ZERO)

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
		if kind == "switch":
			switches.add_child(node, true)
		else:
			room.add_child(node, true)
	room.completion_criteria = completion()
	room.enemy_count = enemy_count()
	return room

# --- Export ---

func to_text() -> String:
	var lines: PackedStringArray = [
		"# Infinite Labyrinth room design, made with the room creator.",
		"# Give this file to Claude to add the room to src/world/rooms/.",
		"version: 1",
		"floor_size: %d" % SIZE,
		"completion: %s" % completion(),
		"enemy_count: %d" % enemy_count(),
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
	return "\n".join(lines) + "\n"
