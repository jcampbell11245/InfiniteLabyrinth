class_name WorldGenerator

# Lays out a floor: which room scene goes in each cell of a 5-row by 8-column grid.
# Column 0 holds only the start room and column 7 only the end room, both in the middle
# row; columns 1..6 are the generated rooms, three of them key rooms
# (Tuning.keys_to_finish of their keys open the end room; a spare carries over). Empty cells are "".
# Pure: it only reads the scene lists and the RNG, and instances nothing.
#
# Room scenes are loaded once and kept (see scene). Godot drops a resource as soon as
# nothing references it, so without the cache every load also reloaded everything the rooms
# share (tile maps, enemies, their textures): about 3 seconds per floor. The title screen
# starts loading them in the background (preload_rooms), so a run usually starts at once.

const LAYOUT_ROWS := 5
const LAYOUT_COLUMNS := 8
const MIDDLE_ROW := 2
const START_ROOM := "res://src/world/special/StartRoom.tscn"
const END_ROOM := "res://src/world/special/EndRoom.tscn"
const ROOMS_DIR := "res://src/world/rooms/"
const KEYROOMS_DIR := "res://src/world/keyrooms/"
const BOSS_ROOM := "res://src/world/special/BossRoom.tscn"

static var _scenes := {} # Scene path -> its PackedScene, kept loaded for the whole session
static var _loading := {} # Scene paths requested in the background and not yet collected

# Returns layout[row][col], a scene path or "" for no room. Generated rooms are picked from
# those allowed on `floor_number` (Room.floors). If there are too few to fill the floor,
# some appear twice; if none are allowed, any room can appear.
static func generate(rng: RandomNumberGenerator, floor_number := 1) -> Array[PackedStringArray]:
	var allowed := rooms_for_floor(list_scenes(ROOMS_DIR), floor_number)
	if allowed.is_empty():
		push_warning("No rooms allowed on floor %d; using every room" % floor_number)
		allowed = list_scenes(ROOMS_DIR)
	var rooms := allowed.duplicate()
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
				if key == -1 && rooms.is_empty(): # Every allowed room used; start again
					rooms = allowed.duplicate()
				scene = keyrooms[key] if key != -1 else _take_random(rng, rooms)
			cells.append(scene)
		layout.append(cells)
	return layout

# The room scene at `path`, loaded once and then kept. One still loading in the background
# is waited for.
static func scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var packed: PackedScene = null
	if _loading.has(path):
		_loading.erase(path)
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		packed = load(path) as PackedScene
	_scenes[path] = packed
	return packed

# Starts loading every room scene a floor can use on background threads, so they're ready
# by the time a run starts. Safe to call again; scenes already loaded or loading are skipped.
# Skipped headless (the smoke test, exports' --headless runs): the dummy renderer there
# isn't safe to create textures on from several threads at once, and logs errors.
static func preload_rooms() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var paths := list_scenes(ROOMS_DIR) + list_scenes(KEYROOMS_DIR)
	paths.append_array([START_ROOM, END_ROOM, BOSS_ROOM])
	for path in paths:
		if _scenes.has(path) || _loading.has(path):
			continue
		if ResourceLoader.load_threaded_request(path, "PackedScene", true) == OK:
			_loading[path] = true

# Waits for every background load preload_rooms started and keeps the scenes. Call it
# before anything else loads scenes the rooms use (enemies, tiles): Godot can hang if the
# main thread loads a scene a background load still holds uncollected.
static func finish_preload() -> void:
	for path: String in _loading.keys():
		scene(path)

static func list_scenes(dir: String) -> Array[String]:
	var scenes: Array[String] = []
	for file_name in ResourceLoader.list_directory(dir):
		if file_name.ends_with(".tscn"):
			scenes.append(dir + file_name)
	return scenes

# The scenes in `scenes` whose room can appear on `floor_number`.
static func rooms_for_floor(scenes: Array[String], floor_number: int) -> Array[String]:
	var allowed: Array[String] = []
	for path in scenes:
		if Room.allowed_on(floor_number, floor_mask(path)):
			allowed.append(path)
	return allowed

# A room scene's Room.floors flags, read from the scene file without instancing it.
static func floor_mask(path: String) -> int:
	var state := scene(path).get_state()
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == &"floors":
			return state.get_node_property_value(0, i)
	return Room.ALL_FLOORS # Room.gd's default, which the scene file leaves out

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
