class_name Room
extends Node2D

# Script on every room scene. On load it dresses the floor (random floor variants,
# decorations, pitfall edges and spikes) and places the door transition detectors.
# While playing it fades with the player's room changes and draws its doors: closed at the
# dungeon edge, locked while the player clears it, opened once it's cleared.
#
# Cells are TileMap coordinates. The floor is floor_size cells square, starting at cell 9 on
# both axes (9..21 for the usual 13x13 floor, 9..17 for the boss room's 9x9), and the doors
# sit just outside it, at the middle of each side.

enum Door { TOP, RIGHT, BOTTOM, LEFT }

const CELL_SIZE := 24 # Pixels per tile
const FLOOR_FIRST := 9 # First floor cell on both axes
const LEFT_WALL := 8 # Column of the left wall
const TOP_WALL := 7 # Top row of the top wall (its face is the row below)
const STANDARD_FLOOR_SIZE := 13
const DETECTION_INSET := 13.0 # The player counts as inside once this far onto the floor

const UnlockSound := preload("res://assets/sfx/dooropen.wav")
const LaserUnlockSound := preload("res://assets/sfx/laser_unlock.wav") # Floor 2 on: the laser bars switch off
const LASER_UNLOCK_VOLUME_DB := -6.0 # The laser is about 7 dB louder than the floor-1 door sound
const KILL_PITCH_STEP := 0.06 # Each kill in a row raises the death sound's pitch this much
const KILL_PITCH_MAX_STEPS := 6

const FLOOR := 0 # Plain floor source ids that get a random variant
const FLOOR_ALT := 4

# Edge overlays drawn round each pitfall cell, by which neighbours are open floor. "T" is
# drawn on the room's own PitfallTransitions layer; the rest are separate TileMap scenes.
const PITFALL_EDGES := {
	"R": preload("res://src/world/tiles/PitfallTransitionsR.tscn"),
	"B": preload("res://src/world/tiles/PitfallTransitionsB.tscn"),
	"L": preload("res://src/world/tiles/PitfallTransitionsL.tscn"),
	"TR": preload("res://src/world/tiles/PitfallTransitionsTR.tscn"),
	"BR": preload("res://src/world/tiles/PitfallTransitionsBR.tscn"),
	"BL": preload("res://src/world/tiles/PitfallTransitionsBL.tscn"),
	"TL": preload("res://src/world/tiles/PitfallTransitionsTL.tscn"),
}
# How far a pit's collision is pulled in from each side that borders floor, in pixels, so
# the ledge art drawn over the pit's edge counts as ground. The top is the deepest because
# the cliff face fills most of the top of a pit cell.
const PIT_INSET_TOP := 12.0
const PIT_INSET_SIDE := 4.0
const PIT_INSET_BOTTOM := 4.0
# Floor 2 on, a locked door is drawn whole on the Locks layer, below the player and the
# door frames on Top, instead of floor 1's inserts under the arch. floor2_lock_cells lists
# its cells, in the order of its Locks sources: red (enemies) pieces from source 9, blue
# (switches) from 18.
const FLOOR2_LOCK_FIRST_SOURCE := {"enemies": 9, "switches": 18}
const TOP_BACK_Z := 0 # The top wall: over the floor, under everything standing on it (z 1 and up)
const BLACK := 16 # Plain black tile, the dark beyond a doorway
# Stalagmite tile source for each set of joined stalagmite neighbours, as a mask of
# 1 top, 2 right, 4 bottom, 8 left. Matches the source order in Stalagmites.tscn.
const STALAGMITE_SOURCES := {
	0: 0, 4: 1, 8: 2, 12: 3, 10: 4, 14: 5, 2: 6, 1: 7,
	5: 8, 9: 9, 13: 10, 11: 11, 15: 12, 3: 13, 7: 14, 6: 15,
}
const PitfallSpikes := preload("res://src/world/tiles/PitfallSpikes.tscn")
const TransitionDetector := preload("res://src/world/tiles/TransitionDetector.tscn")

@export_enum("none", "enemies", "switches") var completion_criteria := "none"
@export var enemy_count := 0
@export var room_id: int
## Width and height of the walkable floor, in cells. Odd, so each door has a middle cell.
@export var floor_size := STANDARD_FLOOR_SIZE
## Camera zoom while the player is in this room.
@export var camera_zoom := 2.5
const FLOOR_CHOICES := 10 # Floors the checklist covers; later floors follow the last one
const ALL_FLOORS := (1 << FLOOR_CHOICES) - 1

## Floors this room can appear on (WorldGenerator reads it). Floors after 10 follow Floor 10.
@export_flags("Floor 1", "Floor 2", "Floor 3", "Floor 4", "Floor 5", "Floor 6", "Floor 7",
	"Floor 8", "Floor 9", "Floor 10") var floors := ALL_FLOORS

# True if a room with the `floors` flags `mask` can appear on `floor_number`.
static func allowed_on(floor_number: int, mask: int) -> bool:
	return mask & (1 << (clampi(floor_number, 1, FLOOR_CHOICES) - 1)) != 0

# The floor whose art rooms are drawn with: the floor being played, or while play-testing
# from the room creator, the tileset picked there.
static func art_floor() -> int:
	if Overworld.test_design != null:
		return Overworld.test_design.preview_floor
	return SaveData.floor_number

# Room geometry, all worked out from floor_size. Points are room-local pixels.
var floor_last: int: # Last floor cell on both axes
	get: return FLOOR_FIRST + floor_size - 1
var far_wall: int: # Column of the right wall, and row of the bottom wall
	get: return FLOOR_FIRST + floor_size
@warning_ignore("integer_division")
var door_line: int: # Column of the top and bottom doors, and row of the side doorways
	get: return FLOOR_FIRST + floor_size / 2
var door_cells: Dictionary: # Door -> its doorway cell
	get: return {
		Door.TOP: Vector2i(door_line, TOP_WALL + 1),
		Door.RIGHT: Vector2i(far_wall, door_line),
		Door.BOTTOM: Vector2i(door_line, far_wall),
		Door.LEFT: Vector2i(LEFT_WALL, door_line),
	}
var floor_rect: Rect2: # The walkable floor
	get: return Rect2(Vector2.ONE * FLOOR_FIRST * CELL_SIZE, Vector2.ONE * floor_size * CELL_SIZE)
var bounds: Rect2: # Every tile of the room, walls included
	get:
		var first := Vector2(LEFT_WALL, TOP_WALL) * CELL_SIZE
		return Rect2(first, Vector2.ONE * (far_wall + 1) * CELL_SIZE - first)
var centre: Vector2: # Centre of the room's tiles
	get: return bounds.get_center()
var floor2_lock_cells: Dictionary:
	get: return {
		Door.TOP: [Vector2i(door_line, TOP_WALL), Vector2i(door_line, TOP_WALL + 1)],
		Door.RIGHT: _side_door_cells(far_wall),
		Door.BOTTOM: [Vector2i(door_line, far_wall)],
		Door.LEFT: _side_door_cells(LEFT_WALL),
	}

var player_active := true # False while the player is down a pitfall; enemies wait
var locked := false # Lock tiles have been drawn (first time the player enters)
var faded_out := true
var doors: Array[bool] = [true, true, true, true] # Open state, indexed by Door
var _detectors: TileMap # Transition detector tiles, one per open doorway
var _key_gate: StaticBody2D # End room only: blocks the top door until the player has Tuning.keys_to_finish keys
var _was_cleared := false # Doors were already unlocked last time they were drawn
var _kill_streak := 0 # Kills in quick succession (Tuning.kill_combo_window); pitches death sounds up
var _last_kill_at := -100000 # Ticks (ms) of the last kill in this room
var _floor2_doors := false # Doors use the floor-2 art and lock drawing
var _top_back: TileMap # The top wall's cells from Top, drawn below everything on the floor
var _top_arch: TileMap # The top door's column of them, raised while the player walks through
var _nav: RoomNav # Enemy pathfinding; see nav()
# Enemies killed in this room, for a necromancer to raise (see raise_fallen): each the
# scene it came from, where it fell (room-local) and what the room had set on it.
var fallen: Array[Dictionary] = []

@onready var goblin_death: AudioStreamPlayer = $GoblinDeath
@onready var knight_death: AudioStreamPlayer = $KnightDeath
@onready var player: Player = Game.player
@onready var fade: AnimationPlayer = $Void/Fade
@onready var tiles: TileMap = $Tiles
@onready var top: TileMap = $Top
@onready var pitfalls: TileMap = $Pitfalls

func _ready() -> void:
	for child in get_children():
		if child is Enemy:
			child.died.connect(_on_enemy_died)
	if completion_criteria == "switches":
		$Switches.switch_hit.connect(_refresh_doors)
	Game.room_entered.connect(_on_room_entered)
	Game.keys_changed.connect(_on_keys_changed)
	fade.animation_finished.connect(_on_fade_finished)

	_fit_cover_and_detection()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_join_stalagmites()
	_add_decorations(rng)
	_add_floor_variants(rng)
	_add_pitfall_edges()
	_trim_pitfall_collision()
	_add_pitfall_spikes(rng)
	_add_transition_detectors()
	_add_door_blockers()
	_split_top_wall()
	_floor2_doors = FloorTheme.uses_floor2_art(art_floor())
	if _floor2_doors:
		_open_side_doorways()
	# Last, so the layers added above get the floor's art too.
	FloorTheme.apply(self, art_floor())

func close_door(door: Door) -> void:
	doors[door] = false
	# The end room's top door is the key gate, which opens later, so it keeps its detector.
	if !(room_id == Constants.END_ROOM && door == Door.TOP):
		_detectors.erase_cell(0, door_cells[door])
	_refresh_doors()

# Blocks the end room's top door. The gate tile has no collision of its own, so this
# body stands in for it until _refresh_doors sees enough keys.
func add_key_gate() -> void:
	var tile_layers: int = tiles.tile_set.get_physics_layer_collision_layer(0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tiles.tile_set.tile_size)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_key_gate = StaticBody2D.new()
	_key_gate.name = "KeyGate"
	_key_gate.collision_layer = tile_layers
	_key_gate.collision_mask = 0
	_key_gate.position = tiles.map_to_local(door_cells[Door.TOP])
	_key_gate.add_child(collision)
	add_child(_key_gate)
	_refresh_doors() # Keys carried over from earlier floors may already be enough

# The point nearest `point` that is at least `margin` inside the floor. Enemies standing
# against a wall overlap it (their origin is above their feet), so projectiles spawn here
# instead of at the enemy, or they would hit the wall the moment they appear.
func clamp_to_floor(point: Vector2, margin: float) -> Vector2:
	var inset := Vector2(margin, margin)
	var rect := floor_rect
	return point.clamp(rect.position + inset, rect.end - inset)

# True when `point` (global) is on the room's floor and not over a pitfall.
func is_floor_at(point: Vector2) -> bool:
	var cell := tiles.local_to_map(tiles.to_local(point))
	return _on_floor(cell) && !_is_pit(cell)

func is_cleared() -> bool:
	match completion_criteria:
		"switches": return $Switches.unlocked()
		"enemies": return enemy_count == 0
	return false

# --- Geometry ---

# Pathfinding round this room's pits and rocks for its enemies, built the first time one
# asks. Call it from a physics callback: building it queries the physics world.
func nav() -> RoomNav:
	if _nav == null:
		_nav = RoomNav.new(self)
	return _nav

func _on_floor(cell: Vector2i) -> bool:
	return cell.x >= FLOOR_FIRST && cell.x <= floor_last && cell.y >= FLOOR_FIRST && cell.y <= floor_last

# A side door's three cells in wall column `x`, top to bottom: two of arch, then the doorway.
func _side_door_cells(x: int) -> Array[Vector2i]:
	return [Vector2i(x, door_line - 2), Vector2i(x, door_line - 1), Vector2i(x, door_line)]

# Floor dressing, as [first cell, last cell, first source id, number of variants]: the
# middle, the top, bottom, left and right edges, then the four corners. A cell holding
# FLOOR or FLOOR_ALT becomes one of the variants at random.
func _floor_variant_areas() -> Array[Array]:
	var a := FLOOR_FIRST
	var b := floor_last
	return [
		[Vector2i(a + 1, a + 1), Vector2i(b - 1, b - 1), 32, 3],
		[Vector2i(a + 1, a), Vector2i(b - 1, a), 39, 2],
		[Vector2i(a + 1, b), Vector2i(b - 1, b), 28, 2],
		[Vector2i(a, a + 1), Vector2i(a, b - 1), 30, 2],
		[Vector2i(b, a + 1), Vector2i(b, b - 1), 37, 2],
		[Vector2i(a, a), Vector2i(a, a), 35, 1],
		[Vector2i(b, a), Vector2i(b, a), 36, 1],
		[Vector2i(a, b), Vector2i(a, b), 26, 1],
		[Vector2i(b, b), Vector2i(b, b), 27, 1],
	]

# The black cover and the player-detection area are shared scenes, so they're fitted to
# this room's size here.
func _fit_cover_and_detection() -> void:
	var cover: ColorRect = $Void/ColorRect
	var rect := bounds
	cover.position = rect.position - Vector2(1, 0) # A pixel past the left wall, as before
	cover.size = rect.size + Vector2(1, 0)
	var detection: CollisionShape2D = $RoomDetection/CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = floor_rect.size - Vector2.ONE * DETECTION_INSET * 2
	detection.shape = shape
	detection.position = floor_rect.get_center()

# --- Floor dressing ---

func _is_floor(cell: Vector2i) -> bool:
	var source := tiles.get_cell_source_id(0, cell)
	return source == FLOOR || source == FLOOR_ALT

func _is_pit(cell: Vector2i) -> bool:
	return pitfalls.get_cell_source_id(0, cell) != -1

# Redraws every stalagmite with the piece that joins it to its stalagmite neighbours, so a
# patch reads as one rock whatever pieces the room scene was painted with.
func _join_stalagmites() -> void:
	var stalagmites: TileMap = get_node_or_null("Stalagmites")
	if stalagmites == null:
		return
	var cells := stalagmites.get_used_cells(0)
	var sources := {} # Cell -> source to draw, worked out before any cell changes
	for cell in cells:
		var mask := 0
		for i in RoomDesign.NEIGHBOURS.size():
			if stalagmites.get_cell_source_id(0, cell + RoomDesign.NEIGHBOURS[i]) != -1:
				mask |= 1 << i
		sources[cell] = STALAGMITE_SOURCES[mask]
	for cell: Vector2i in sources:
		stalagmites.set_cell(0, cell, sources[cell], Vector2i.ZERO)

func _add_decorations(rng: RandomNumberGenerator) -> void:
	var decorations: TileMap = get_node_or_null("Decorations")
	if decorations == null:
		return
	var stalagmites: TileMap = get_node_or_null("Stalagmites")
	for x in range(FLOOR_FIRST, floor_last):
		for y in range(FLOOR_FIRST, floor_last):
			var cell := Vector2i(x, y)
			if tiles.get_cell_source_id(0, cell) != FLOOR || _is_pit(cell):
				continue
			if stalagmites != null && stalagmites.get_cell_source_id(0, cell) != -1:
				continue
			# 8 in 67 floor tiles get a decoration: 0 is the rarest, 1 the most common.
			var roll := rng.randi_range(0, 66)
			if roll == 59:
				decorations.set_cell(0, cell, 0, Vector2i.ZERO)
			elif roll >= 60 && roll < 64:
				decorations.set_cell(0, cell, 1, Vector2i.ZERO)
			elif roll >= 64 && roll < 66:
				decorations.set_cell(0, cell, 2, Vector2i.ZERO)
			elif roll == 66:
				decorations.set_cell(0, cell, 3, Vector2i.ZERO)

func _add_floor_variants(rng: RandomNumberGenerator) -> void:
	for area: Array in _floor_variant_areas():
		var first: Vector2i = area[0]
		var last: Vector2i = area[1]
		var first_source: int = area[2]
		var variants: int = area[3]
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if _is_floor(cell):
					tiles.set_cell(0, cell, first_source + rng.randi_range(0, variants - 1), Vector2i.ZERO)

func _add_pitfall_edges() -> void:
	var top_layer: TileMap = get_node_or_null("PitfallTransitions")
	if top_layer == null:
		return
	var layers := {}
	for key: String in PITFALL_EDGES:
		var layer: TileMap = PITFALL_EDGES[key].instantiate()
		layer.z_index = -1
		layers[key] = layer

	for x in range(FLOOR_FIRST, floor_last + 1):
		for y in range(FLOOR_FIRST, floor_last + 1):
			var cell := Vector2i(x, y)
			if !_is_pit(cell):
				continue
			var open_top := !_is_pit(cell + Vector2i.UP)
			var open_right := !_is_pit(cell + Vector2i.RIGHT)
			var open_bottom := !_is_pit(cell + Vector2i.DOWN)
			var open_left := !_is_pit(cell + Vector2i.LEFT)
			if open_top:
				top_layer.set_cell(0, cell, 0, Vector2i.ZERO)
				top_layer.z_index = -1
			var edges := {"R": open_right, "B": open_bottom, "L": open_left,
				"TR": open_top && open_right, "BR": open_bottom && open_right,
				"BL": open_bottom && open_left, "TL": open_top && open_left}
			for key: String in edges:
				if edges[key]:
					layers[key].set_cell(0, cell, 0, Vector2i.ZERO)

	for key: String in layers:
		var layer: TileMap = layers[key]
		if layer.get_used_cells(0).is_empty():
			layer.free()
		else:
			add_child(layer)

# Swaps every pit cell for a tile whose collision stops short of the sides that border
# floor, by the PIT_INSET amounts. Pit tiles all look the same (plain black), so only the
# collision changes.
func _trim_pitfall_collision() -> void:
	if get_node_or_null("Pitfalls") == null:
		return
	var masks := {}
	for cell: Vector2i in pitfalls.get_used_cells(0):
		var mask := 0
		if !_is_pit(cell + Vector2i.UP): mask |= 1
		if !_is_pit(cell + Vector2i.RIGHT): mask |= 2
		if !_is_pit(cell + Vector2i.DOWN): mask |= 4
		if !_is_pit(cell + Vector2i.LEFT): mask |= 8
		masks[cell] = mask
	for cell: Vector2i in masks:
		pitfalls.set_cell(0, cell, 0, Vector2i.ZERO, _trimmed_pit_tile(masks[cell]))

# The alternative of pit source 0 trimmed for `mask` (1 top, 2 right, 4 bottom, 8 left
# open). Rooms share the pit TileSet, so each one is made once and remembered on it.
func _trimmed_pit_tile(mask: int) -> int:
	var tile_set := pitfalls.tile_set
	var made: Dictionary = tile_set.get_meta("trimmed_pits", {})
	if made.has(mask):
		return made[mask]
	var source: TileSetAtlasSource = tile_set.get_source(0)
	var alt := source.create_alternative_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, alt)
	var half := tile_set.tile_size.x / 2.0
	var top := -half + (PIT_INSET_TOP if mask & 1 else 0.0)
	var right := half - (PIT_INSET_SIDE if mask & 2 else 0.0)
	var bottom := half - (PIT_INSET_BOTTOM if mask & 4 else 0.0)
	var left := -half + (PIT_INSET_SIDE if mask & 8 else 0.0)
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]))
	made[mask] = alt
	tile_set.set_meta("trimmed_pits", made)
	return alt

func _add_pitfall_spikes(rng: RandomNumberGenerator) -> void:
	if get_node_or_null("Pitfalls") == null:
		return
	var spikes: TileMap = PitfallSpikes.instantiate()
	for x in range(FLOOR_FIRST, floor_last):
		for y in range(FLOOR_FIRST, floor_last):
			var cell := Vector2i(x, y)
			if _is_pit(cell) && rng.randi_range(0, 3) == 0:
				spikes.set_cell(0, cell, 0, Vector2i.ZERO)
	add_child(spikes)

# Detector tiles in each doorway that start the walk into the next room. close_door()
# removes the ones in doorways that get closed. Each spans the doorway's whole width, so
# feet that come in along one edge of the opening (walking in at an angle) still set it
# off instead of leaving the player standing in the doorway; the side doors use a copy
# turned on its side.
const DETECTOR_ACROSS_X := 0 # Tile alternative for the top and bottom doors
const DETECTOR_ACROSS_Y := 8 # For the side doors

func _add_transition_detectors() -> void:
	_detectors = TransitionDetector.instantiate()
	var cells := door_cells
	for door: Door in cells:
		var side := door == Door.LEFT || door == Door.RIGHT
		_detectors.set_cell(0, cells[door], 0, Vector2i.ZERO,
			DETECTOR_ACROSS_Y if side else DETECTOR_ACROSS_X)
	add_child(_detectors)

# Fills every doorway with a block on the top-tiles layer, which enemies (and enemy
# projectiles) collide with but the player doesn't. Without it, an enemy that outlives the
# doors' locks (a knight in a switch room) can walk into a doorway and under its arch.
func _add_door_blockers() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tiles.tile_set.tile_size)
	var cells := door_cells
	for door: Door in cells:
		var collision := CollisionShape2D.new()
		collision.shape = shape
		var blocker := StaticBody2D.new()
		blocker.name = "DoorBlocker%d" % door
		blocker.collision_layer = 0
		blocker.set_collision_layer_value(Constants.Layer.TOP_TILES, true)
		blocker.collision_mask = 0
		blocker.position = tiles.map_to_local(cells[door])
		blocker.add_child(collision)
		add_child(blocker)

# Moves the top wall (Top's rows above the floor) onto layers below everything standing on
# the floor. Top draws over characters so they pass behind the side and bottom walls, but
# the top wall is always behind them; on Top it cut off the heads of tall enemies standing
# against it. The top door's column gets a layer of its own, which set_arch_in_front()
# raises while the player walks through the door, so they still pass under the arch.
func _split_top_wall() -> void:
	_top_back = _new_top_layer("TopBack")
	_top_arch = _new_top_layer("TopArch")
	var arch_x := door_line
	for cell: Vector2i in top.get_used_cells(0):
		if cell.y < FLOOR_FIRST:
			var layer := _top_arch if cell.x == arch_x else _top_back
			layer.set_cell(0, cell, top.get_cell_source_id(0, cell),
				top.get_cell_atlas_coords(0, cell), top.get_cell_alternative_tile(0, cell))
			top.erase_cell(0, cell)

func _new_top_layer(layer_name: String) -> TileMap:
	var layer := TileMap.new()
	layer.name = layer_name
	layer.tile_set = top.tile_set
	layer.z_index = TOP_BACK_Z
	add_child(layer)
	return layer

# Draws the top door's arch over the player (while they walk through it) or back behind
# everything on the floor.
func set_arch_in_front(in_front: bool) -> void:
	_top_arch.z_index = top.z_index if in_front else TOP_BACK_Z

# --- Doors ---

# Redraws the door tiles from the room's state. Safe to call any number of times.
func _refresh_doors() -> void:
	_draw_closed_doors()
	if room_id == Constants.END_ROOM && Game.keys >= Tuning.keys_to_finish:
		tiles.set_cell(0, door_cells[Door.TOP], 1, Vector2i.ZERO)
		if _key_gate != null:
			_key_gate.queue_free()
			_key_gate = null
	if is_cleared():
		_draw_unlocked_doors()
		if locked && !_was_cleared:
			_celebrate_unlock()
	_was_cleared = is_cleared()

# The payoff for clearing a locked room: a heavy unlock sound, a thud and dust at each door.
func _celebrate_unlock() -> void:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"SFX"
	sound.stream = LaserUnlockSound if _floor2_doors else UnlockSound
	if _floor2_doors:
		sound.volume_db = LASER_UNLOCK_VOLUME_DB
	add_child(sound)
	# The floor-1 door is pitched down for weight; the laser plays as recorded.
	Juice.play(sound, 0.03, 1.0 if _floor2_doors else 0.8)
	sound.finished.connect(sound.queue_free)
	Juice.shake(Juice.SHAKE_MEDIUM)
	var cells := door_cells
	for door: Door in cells:
		if doors[door]:
			var at := tiles.to_global(tiles.map_to_local(cells[door]))
			Juice.burst(self, at, Color(0.75, 0.7, 0.6), 12, 50.0, Vector2.ZERO, 2.5, 0.6)

func _draw_closed_doors() -> void:
	# A floor-2 lock would show over the walls drawn for a closed door.
	var locks: TileMap = get_node_or_null("Locks")
	if _floor2_doors && locks != null:
		var lock_cells := floor2_lock_cells
		for door: Door in lock_cells:
			if !doors[door]:
				for cell: Vector2i in lock_cells[door]:
					locks.erase_cell(0, cell)
	var cells := door_cells
	# The end room's top door is the key gate, opened by the keys instead.
	if !doors[Door.TOP] && room_id != Constants.END_ROOM:
		tiles.set_cell(0, cells[Door.TOP], 6, Vector2i.ZERO)
		_top_arch.set_cell(0, cells[Door.TOP], 3, Vector2i.ZERO)
		_top_arch.set_cell(0, cells[Door.TOP] + Vector2i.UP, 1, Vector2i.ZERO)
	if !doors[Door.RIGHT]:
		for cell in _side_door_cells(far_wall):
			top.set_cell(0, cell, 12, Vector2i.ZERO)
			tiles.set_cell(0, cell, 10, Vector2i.ZERO)
	if !doors[Door.BOTTOM]:
		tiles.set_cell(0, cells[Door.BOTTOM], 5, Vector2i.ZERO)
		top.set_cell(0, cells[Door.BOTTOM], 3, Vector2i.ZERO)
	if !doors[Door.LEFT]:
		for cell in _side_door_cells(LEFT_WALL):
			top.set_cell(0, cell, 4, Vector2i.ZERO)
			tiles.set_cell(0, cell, 7, Vector2i.ZERO)

# Floor 2's open side doors show the dark beyond the doorway through the frame, where
# floor 1 has wall above the passage. The upper two cells keep their collision (FLOOR_ALT
# is see-through but solid) and the wall overlay comes off. Closing a door redraws the wall.
func _open_side_doorways() -> void:
	var top_walls: TileMap = get_node_or_null("TopWalls")
	var sides: Array[Door] = [Door.RIGHT, Door.LEFT]
	# The boss door is a sprite drawn over the wall (start room left, boss room right).
	if has_node("BossDoor"):
		sides.erase(Door.LEFT)
	if has_node("BossDoorBody"):
		sides.erase(Door.RIGHT)
	for door in sides:
		var side_cells := _side_door_cells(far_wall if door == Door.RIGHT else LEFT_WALL)
		for i in range(side_cells.size()):
			var cell := side_cells[i]
			tiles.set_cell(0, cell, BLACK if i == side_cells.size() - 1 else FLOOR_ALT, Vector2i.ZERO)
			if top_walls != null:
				top_walls.erase_cell(0, cell)

# Lock tiles differ by what clears the room: switches or enemies. Closed doors are
# redrawn over them straight after, except on the Locks layer.
func _draw_locks() -> void:
	var switches := completion_criteria == "switches"
	if !switches && completion_criteria != "enemies":
		return
	var locks: TileMap = $Locks
	if _floor2_doors:
		# Only open doors get a lock, since the walls of a closed one don't cover it.
		var source: int = FLOOR2_LOCK_FIRST_SOURCE[completion_criteria]
		var lock_cells := floor2_lock_cells
		for door: Door in lock_cells:
			for cell: Vector2i in lock_cells[door]:
				if doors[door]:
					locks.set_cell(0, cell, source, Vector2i.ZERO)
				source += 1
		return
	var cells := door_cells
	tiles.set_cell(0, cells[Door.TOP], 21 if switches else 20, Vector2i.ZERO)
	locks.set_cell(0, cells[Door.LEFT], 1 if switches else 0, Vector2i.ZERO)
	locks.set_cell(0, cells[Door.LEFT] + Vector2i.UP, 5 if switches else 4, Vector2i.ZERO)
	tiles.set_cell(0, cells[Door.BOTTOM], 18, Vector2i.ZERO)
	locks.set_cell(0, cells[Door.RIGHT], 2 if switches else 3, Vector2i.ZERO)
	locks.set_cell(0, cells[Door.RIGHT] + Vector2i.UP, 6 if switches else 7, Vector2i.ZERO)

func _draw_unlocked_doors() -> void:
	var locks: TileMap = get_node_or_null("Locks")
	if _floor2_doors:
		if locks != null:
			var lock_cells := floor2_lock_cells
			for door: Door in lock_cells:
				if doors[door]:
					for cell: Vector2i in lock_cells[door]:
						locks.erase_cell(0, cell)
		return
	var cells := door_cells
	if doors[Door.TOP]:
		tiles.set_cell(0, cells[Door.TOP], 1, Vector2i.ZERO)
	if doors[Door.LEFT]:
		locks.set_cell(0, cells[Door.LEFT], 8, Vector2i.ZERO)
		locks.set_cell(0, cells[Door.LEFT] + Vector2i.UP, 8, Vector2i.ZERO)
	if doors[Door.BOTTOM]:
		tiles.set_cell(0, cells[Door.BOTTOM], 16, Vector2i.ZERO)
	if doors[Door.RIGHT]:
		locks.set_cell(0, cells[Door.RIGHT], 8, Vector2i.ZERO)
		locks.set_cell(0, cells[Door.RIGHT] + Vector2i.UP, 8, Vector2i.ZERO)

# --- Signals ---

func _on_room_entered(id: int) -> void:
	if id != room_id && !faded_out:
		fade.play("FadeOut")
		faded_out = true
	elif id == room_id && faded_out:
		fade.play("FadeIn")
		faded_out = false
	if id == room_id:
		_kill_streak = 0

	# Lock the doors the first time the player comes in.
	if id == room_id && !locked && get_node_or_null("Locks") != null:
		locked = true
		_draw_locks()
	_refresh_doors()

# Once the room has faded to black behind a player who left, any enemy still alive goes
# back to where it started, unseen. (A player who turns back before the fade ends cuts it
# short, and finds the enemies where they left them.)
func _on_fade_finished(anim_name: StringName) -> void:
	if anim_name != "FadeOut":
		return
	for child in get_children():
		var enemy := child as Enemy
		if enemy != null && !enemy.is_queued_for_deletion():
			enemy.reset_to_spawn()

func _on_keys_changed(_keys: int) -> void:
	_refresh_doors()

# Death sounds live on the room because the enemy is freed as it dies. Keyed by the
# enemy's scene file name; wizards have none. Each kill within Tuning.kill_combo_window of
# the last pitches the sound up, like a combo; a slower kill starts again at normal pitch.
func _on_enemy_died(enemy: Enemy) -> void:
	enemy_count -= 1
	_remember_fallen(enemy)
	var now := Time.get_ticks_msec() # Real time, so hit-stop doesn't stretch the window
	if now - _last_kill_at > Tuning.kill_combo_window * 1000:
		_kill_streak = 0
	_last_kill_at = now
	var pitch := 1.0 + KILL_PITCH_STEP * mini(_kill_streak, KILL_PITCH_MAX_STEPS)
	_kill_streak += 1
	match enemy.scene_file_path.get_file().get_basename():
		# The rest of the goblin family share its death sound, at their own voice_pitch.
		"Goblin", "Troll", "Orc": Juice.play(goblin_death, 0.04, pitch * enemy.voice_pitch)
		"Knight", "DualKnight": Juice.play(knight_death, 0.04, pitch)
	_refresh_doors()

# --- The fallen (see Necromancer) ---

# What a room sets on the enemies it places, carried over to one raised again.
# Never raised: necromancers (by each other or anyone) and the boss.
const NECROMANCER_SCENE := "res://src/enemies/Necromancer.tscn"
const BOSS_SCENE := "res://src/enemies/Boss.tscn"
const RAISED_KEEPS: Array[String] = ["starting_direction", "detection_radius", "roam_mode", "roam_path", "roam_area"]

func _remember_fallen(enemy: Enemy) -> void:
	if enemy.scene_file_path in ["", NECROMANCER_SCENE, BOSS_SCENE]:
		return
	var kept := {}
	for property in RAISED_KEEPS:
		if property in enemy:
			kept[property] = enemy.get(property)
	fallen.append({scene = enemy.scene_file_path, position = enemy.position, kept = kept})

# Brings fallen[index] back to life where it fell, or on the nearest open floor cell if
# that spot is a pit, rock or wall (it was knocked over a pit edge, say). It knows the
# player is there and joins the fight at once, and counts towards clearing the room
# again. Returns it, or null if there was nowhere to put it.
func raise_fallen(index: int) -> Enemy:
	var record: Dictionary = fallen[index]
	var enemy: Enemy = (load(record.scene) as PackedScene).instantiate()
	for property: String in record.kept:
		enemy.set(property, record.kept[property])
	var feet := Enemy.FEET_OFFSET
	var spot: Variant = nav().nearest_open(record.position + feet)
	if spot == null:
		return null
	fallen.remove_at(index)
	enemy.position = (spot as Vector2) - feet
	add_child(enemy, true)
	enemy.died.connect(_on_enemy_died)
	enemy_count += 1
	if "noticed" in enemy:
		enemy.noticed = true
	_refresh_doors()
	return enemy

func _on_next_floor_area_entered(_area: Area2D) -> void:
	Game.finish_floor()
	SaveData.floor_number = Game.overworld.floor_number + 1
	Game.upgrade_menu.show_menu()

func _on_boss_door_animation_finished() -> void:
	if $BossDoor.animation == "opening":
		player.start_transition()
