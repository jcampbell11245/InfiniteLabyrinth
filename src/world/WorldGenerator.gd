class_name WorldGenerator

# Lays out a floor: which room scene goes in each cell of a 5-row by 8-column grid.
# Column 0 holds only the start room and column 7 only the end room, both in the middle
# row; columns 1..6 are the generated rooms, three of them key rooms. Empty cells are null.
# Pure: it only reads the scene lists and the RNG, and instances nothing.

const LAYOUT_ROWS = 5
const LAYOUT_COLUMNS = 8
const MIDDLE_ROW = 2
const START_ROOM = "res://src/world/special/StartRoom.tscn"
const END_ROOM = "res://src/world/special/EndRoom.tscn"
const ROOMS_DIR = "res://src/world/rooms/"
const KEYROOMS_DIR = "res://src/world/keyrooms/"

# Returns layout[row][col], a scene path or null.
static func generate(rng):
	var rooms = list_scenes(ROOMS_DIR)
	var keyrooms = list_scenes(KEYROOMS_DIR)

	# Three key rooms in distinct generated columns and distinct rows.
	var key_cols = _distinct_rolls(rng, 3, 1, 6)
	var key_rows = _distinct_rolls(rng, 3, 0, 4)

	var layout = []
	for row in range(LAYOUT_ROWS):
		layout.append([])
		for col in range(LAYOUT_COLUMNS):
			var scene = null
			if(col == 0):
				scene = START_ROOM if row == MIDDLE_ROW else null
			elif(col == LAYOUT_COLUMNS - 1):
				scene = END_ROOM if row == MIDDLE_ROW else null
			else:
				var key = _key_at(key_rows, key_cols, row, col)
				scene = keyrooms[key] if key != -1 else _take_random(rng, rooms)
			layout[row].append(scene)
	return layout

static func list_scenes(dir):
	var scenes = []
	for file_name in ResourceLoader.list_directory(dir):
		if file_name.ends_with(".tscn"):
			scenes.append(dir + file_name)
	return scenes

static func _distinct_rolls(rng, count, low, high):
	var rolls = []
	for _i in range(count):
		var roll = rng.randi_range(low, high)
		while (roll in rolls):
			roll = rng.randi_range(low, high)
		rolls.append(roll)
	return rolls

static func _key_at(key_rows, key_cols, row, col):
	for i in range(key_rows.size()):
		if(key_rows[i] == row && key_cols[i] == col):
			return i
	return -1

# Removes and returns a random entry, so no room appears twice.
static func _take_random(rng, scenes):
	var scene = scenes[rng.randi_range(0, scenes.size() - 1)]
	scenes.erase(scene)
	return scene
