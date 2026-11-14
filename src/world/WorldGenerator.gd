class_name WorldGenerator

# Lays out a floor: which room scene goes in each cell of a 5-row by 8-column grid.
# Column 0 holds only the start room and column 7 only the end room, both in the middle
# row; columns 1..6 are the generated rooms, three of them key rooms. Empty cells are "".
# Pure: it only reads the scene lists and the RNG, and instances nothing.

const LAYOUT_ROWS := 5
const LAYOUT_COLUMNS := 8
const MIDDLE_ROW := 2
const START_ROOM := "res://src/world/special/StartRoom.tscn"
const END_ROOM := "res://src/world/special/EndRoom.tscn"
const ROOMS_DIR := "res://src/world/rooms/"
const KEYROOMS_DIR := "res://src/world/keyrooms/"

# Returns layout[row][col], a scene path or "" for no room.
static func generate(rng: RandomNumberGenerator) -> Array[PackedStringArray]:
	var rooms := list_scenes(ROOMS_DIR)
	var keyrooms := list_scenes(KEYROOMS_DIR)
	
	# Three key rooms in distinct generated columns and distinct rows.
	var key_cols := _distinct_rolls(rng, 3, 1, 6)
	var key_rows := _distinct_rolls(rng, 3, 0, 4)
	
	var layout: Array[PackedStringArray] = []
	for row in range(LAYOUT_ROWS):
		var cells := PackedStringArray()
		for col in range(LAYOUT_COLUMNS):
			var scene := ""
			if col == 0:
				scene = START_ROOM if row == MIDDLE_ROW else ""
			elif col == LAYOUT_COLUMNS - 1:
				scene = END_ROOM if row == MIDDLE_ROW else ""
			else:
				var key := _key_at(key_rows, key_cols, row, col)
				scene = keyrooms[key] if key != -1 else _take_random(rng, rooms)
			cells.append(scene)
		layout.append(cells)
	return layout

static func list_scenes(dir: String) -> Array[String]:
	var scenes: Array[String] = []
	for file_name in ResourceLoader.list_directory(dir):
		if file_name.ends_with(".tscn"):
			scenes.append(dir + file_name)
	return scenes

static func _distinct_rolls(rng: RandomNumberGenerator, count: int, low: int, high: int) -> PackedInt32Array:
	var rolls := PackedInt32Array()
	for _i in range(count):
		var roll := rng.randi_range(low, high)
		while roll in rolls:
			roll = rng.randi_range(low, high)
		rolls.append(roll)
	return rolls

static func _key_at(key_rows: PackedInt32Array, key_cols: PackedInt32Array, row: int, col: int) -> int:
	for i in range(key_rows.size()):
		if key_rows[i] == row && key_cols[i] == col:
			return i
	return -1

# Removes and returns a random entry, so no room appears twice.
static func _take_random(rng: RandomNumberGenerator, scenes: Array[String]) -> String:
	var index := rng.randi_range(0, scenes.size() - 1)
	var scene := scenes[index]
	scenes.remove_at(index)
	return scene
