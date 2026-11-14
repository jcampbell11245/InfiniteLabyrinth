class_name Room
extends Node2D

# Script on every room scene. On load it dresses the floor (random floor variants,
# decorations, pitfall edges and spikes) and places the door transition detectors.
# While playing it fades with the player's room changes and draws its doors: closed at the
# dungeon edge, locked while the player clears it, opened once it's cleared.
#
# Cells are TileMap coordinates. The floor spans cells 9..17 on both axes and the doors
# sit just outside it, at the middle of each side.

enum Door { TOP, RIGHT, BOTTOM, LEFT }

const CENTRE := Vector2(324, 312) # Centre of the room's tiles (cells 8..18 by 7..18)
const FLOOR_RECT := Rect2(216, 216, 216, 216) # The 9x9 walkable floor, cells 9..17
const DOOR_CELLS := { # Doorway cell on each side
	Door.TOP: Vector2i(13, 8),
	Door.RIGHT: Vector2i(18, 13),
	Door.BOTTOM: Vector2i(13, 18),
	Door.LEFT: Vector2i(8, 13),
}

const FLOOR := 0 # Plain floor source ids that get a random variant
const FLOOR_ALT := 4

# Floor dressing, as [first cell, last cell, first source id, number of variants].
# A cell holding FLOOR or FLOOR_ALT becomes one of the variants at random.
const FLOOR_VARIANTS := [
	[Vector2i(10, 10), Vector2i(16, 16), 32, 3], # Middle
	[Vector2i(10, 9), Vector2i(16, 9), 39, 2], # Top edge
	[Vector2i(10, 17), Vector2i(16, 17), 28, 2], # Bottom edge
	[Vector2i(9, 10), Vector2i(9, 16), 30, 2], # Left edge
	[Vector2i(17, 10), Vector2i(17, 16), 37, 2], # Right edge
	[Vector2i(9, 9), Vector2i(9, 9), 35, 1], # Corners
	[Vector2i(17, 9), Vector2i(17, 9), 36, 1],
	[Vector2i(9, 17), Vector2i(9, 17), 26, 1],
	[Vector2i(17, 17), Vector2i(17, 17), 27, 1],
]

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
const PitfallSpikes := preload("res://src/world/tiles/PitfallSpikes.tscn")
const TransitionDetector := preload("res://src/world/tiles/TransitionDetector.tscn")

@export_enum("none", "enemies", "switches") var completion_criteria := "none"
@export var enemy_count := 0
@export var room_id: int

var player_active := true # False while the player is down a pitfall; enemies wait
var locked := false # Lock tiles have been drawn (first time the player enters)
var faded_out := true
var doors: Array[bool] = [true, true, true, true] # Open state, indexed by Door
var _detectors: TileMap # Transition detector tiles, one per open doorway
var _key_gate: StaticBody2D # End room only: blocks the top door until the player has 3 keys

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

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_add_decorations(rng)
	_add_floor_variants(rng)
	_add_pitfall_edges()
	_add_pitfall_spikes(rng)
	_add_transition_detectors()

func close_door(door: Door) -> void:
	doors[door] = false
	# The end room's top door is the key gate, which opens later, so it keeps its detector.
	if !(room_id == Constants.END_ROOM && door == Door.TOP):
		_detectors.erase_cell(0, DOOR_CELLS[door])
	_refresh_doors()

# Blocks the end room's top door. The gate tile has no collision of its own, so this
# body stands in for it until _refresh_doors sees three keys.
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
	_key_gate.position = tiles.map_to_local(Vector2i(13, 8))
	_key_gate.add_child(collision)
	add_child(_key_gate)

# The point nearest `point` that is at least `margin` inside the floor. Enemies standing
# against a wall overlap it (their origin is above their feet), so projectiles spawn here
# instead of at the enemy, or they would hit the wall the moment they appear.
func clamp_to_floor(point: Vector2, margin: float) -> Vector2:
	var inset := Vector2(margin, margin)
	return point.clamp(FLOOR_RECT.position + inset, FLOOR_RECT.end - inset)

func is_cleared() -> bool:
	match completion_criteria:
		"switches": return $Switches.unlocked()
		"enemies": return enemy_count == 0
	return false

# --- Floor dressing ---

func _is_floor(cell: Vector2i) -> bool:
	var source := tiles.get_cell_source_id(0, cell)
	return source == FLOOR || source == FLOOR_ALT

func _is_pit(cell: Vector2i) -> bool:
	return pitfalls.get_cell_source_id(0, cell) != -1

func _add_decorations(rng: RandomNumberGenerator) -> void:
	var decorations: TileMap = get_node_or_null("Decorations")
	if decorations == null:
		return
	var stalagmites: TileMap = get_node_or_null("Stalagmites")
	for x in range(9, 17):
		for y in range(9, 17):
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
	for area: Array in FLOOR_VARIANTS:
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

	for x in range(9, 18):
		for y in range(9, 18):
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

func _add_pitfall_spikes(rng: RandomNumberGenerator) -> void:
	if get_node_or_null("Pitfalls") == null:
		return
	var spikes: TileMap = PitfallSpikes.instantiate()
	for x in range(9, 17):
		for y in range(9, 17):
			var cell := Vector2i(x, y)
			if _is_pit(cell) && rng.randi_range(0, 3) == 0:
				spikes.set_cell(0, cell, 0, Vector2i.ZERO)
	add_child(spikes)

# Detector tiles in each doorway that start the walk into the next room. close_door()
# removes the ones in doorways that get closed.
func _add_transition_detectors() -> void:
	_detectors = TransitionDetector.instantiate()
	for door: Door in DOOR_CELLS:
		_detectors.set_cell(0, DOOR_CELLS[door], 0, Vector2i.ZERO)
	add_child(_detectors)

# --- Doors ---

# Redraws the door tiles from the room's state. Safe to call any number of times.
func _refresh_doors() -> void:
	_draw_closed_doors()
	if room_id == Constants.END_ROOM && Game.keys == 3:
		tiles.set_cell(0, Vector2i(13, 8), 1, Vector2i.ZERO)
		if _key_gate != null:
			_key_gate.queue_free()
			_key_gate = null
	if is_cleared():
		_draw_unlocked_doors()

func _draw_closed_doors() -> void:
	# The end room's top door is the key gate, opened by the keys instead.
	if !doors[Door.TOP] && room_id != Constants.END_ROOM:
		tiles.set_cell(0, Vector2i(13, 8), 6, Vector2i.ZERO)
		top.set_cell(0, Vector2i(13, 8), 3, Vector2i.ZERO)
		top.set_cell(0, Vector2i(13, 7), 1, Vector2i.ZERO)
	if !doors[Door.RIGHT]:
		for y in range(11, 14):
			top.set_cell(0, Vector2i(18, y), 12, Vector2i.ZERO)
			tiles.set_cell(0, Vector2i(18, y), 10, Vector2i.ZERO)
	if !doors[Door.BOTTOM]:
		tiles.set_cell(0, Vector2i(13, 18), 5, Vector2i.ZERO)
		top.set_cell(0, Vector2i(13, 18), 3, Vector2i.ZERO)
	if !doors[Door.LEFT]:
		for y in range(11, 14):
			top.set_cell(0, Vector2i(8, y), 4, Vector2i.ZERO)
			tiles.set_cell(0, Vector2i(8, y), 7, Vector2i.ZERO)

# Lock tiles differ by what clears the room: switches or enemies. Closed doors are
# redrawn over them straight after, except on the Locks layer.
func _draw_locks() -> void:
	var switches := completion_criteria == "switches"
	if !switches && completion_criteria != "enemies":
		return
	var locks: TileMap = $Locks
	tiles.set_cell(0, Vector2i(13, 8), 21 if switches else 20, Vector2i.ZERO)
	locks.set_cell(0, Vector2i(8, 13), 1 if switches else 0, Vector2i.ZERO)
	locks.set_cell(0, Vector2i(8, 12), 5 if switches else 4, Vector2i.ZERO)
	tiles.set_cell(0, Vector2i(13, 18), 18, Vector2i.ZERO)
	locks.set_cell(0, Vector2i(18, 13), 2 if switches else 3, Vector2i.ZERO)
	locks.set_cell(0, Vector2i(18, 12), 6 if switches else 7, Vector2i.ZERO)

func _draw_unlocked_doors() -> void:
	var locks: TileMap = get_node_or_null("Locks")
	if doors[Door.TOP]:
		tiles.set_cell(0, Vector2i(13, 8), 1, Vector2i.ZERO)
	if doors[Door.LEFT]:
		locks.set_cell(0, Vector2i(8, 13), 8, Vector2i.ZERO)
		locks.set_cell(0, Vector2i(8, 12), 8, Vector2i.ZERO)
	if doors[Door.BOTTOM]:
		tiles.set_cell(0, Vector2i(13, 18), 16, Vector2i.ZERO)
	if doors[Door.RIGHT]:
		locks.set_cell(0, Vector2i(18, 13), 8, Vector2i.ZERO)
		locks.set_cell(0, Vector2i(18, 12), 8, Vector2i.ZERO)

# --- Signals ---

func _on_room_entered(id: int) -> void:
	if id != room_id && !faded_out:
		fade.play("FadeOut")
		faded_out = true
	elif id == room_id && faded_out:
		fade.play("FadeIn")
		faded_out = false

	# Lock the doors the first time the player comes in.
	if id == room_id && !locked && get_node_or_null("Locks") != null:
		locked = true
		_draw_locks()
	_refresh_doors()

func _on_keys_changed(_keys: int) -> void:
	_refresh_doors()

# Death sounds live on the room because the enemy is freed as it dies. Keyed by the
# enemy's scene file name; wizards have none.
func _on_enemy_died(enemy: Enemy) -> void:
	enemy_count -= 1
	match enemy.scene_file_path.get_file().get_basename():
		"Goblin": goblin_death.play()
		"Knight": knight_death.play()
	_refresh_doors()

func _on_next_floor_area_entered(_area: Area2D) -> void:
	SaveData.floor_number = Game.overworld.floor_number + 1
	Game.upgrade_menu.show_menu()

func _on_boss_door_animation_finished() -> void:
	if $BossDoor.animation == "opening":
		player.start_transition()
