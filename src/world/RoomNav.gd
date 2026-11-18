class_name RoomNav
extends RefCounted

# Pathfinding for enemies walking a room's floor: a grid of its floor cells with every cell
# that has something solid in it (pits, stalagmites, wall pieces) marked blocked, found by
# asking the physics world rather than reading tiles, so it covers anything a room puts on
# its floor. Built once per room, the first time an enemy needs it (Room.nav()).
#
# Enemies ask next_waypoint() where to head for: straight at the target when nothing is in
# the way, otherwise the furthest point along the A* path round the obstacles that they can
# walk straight to. Points are room-local pixels, measured at the enemy's feet.

# Physics layers that stop an enemy's feet: general walls and rocks, pitfalls, wall tops.
const SOLID_MASK := (1 << (Constants.Layer.GENERAL - 1)) | (1 << (Constants.Layer.PITFALL - 1)) \
	| (1 << (Constants.Layer.TOP_TILES - 1))
const PROBE_SIZE := Vector2(16, 16) # Pixels; a cell is blocked if this much of its middle hits something
const LINE_STEP := 4.0 # Pixels between the checks along a straight walk
const FEET_HALF_WIDTH := 6.0 # Pixels either side of a walk's line that must be clear too

var _grid := AStarGrid2D.new()
var _region: Rect2i

func _init(room: Room) -> void:
	var cell := Room.CELL_SIZE
	_region = Rect2i(Vector2i.ONE * Room.FLOOR_FIRST, Vector2i.ONE * room.floor_size)
	_grid.region = _region
	_grid.cell_size = Vector2.ONE * cell
	_grid.offset = Vector2.ONE * cell / 2.0 # Points at cell centres, in room-local pixels
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()

	var space := room.get_world_2d().direct_space_state
	var probe := RectangleShape2D.new()
	probe.size = PROBE_SIZE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = SOLID_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for y in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var centre := _cell_centre(Vector2i(x, y))
			query.transform = Transform2D(0, room.to_global(centre))
			if !space.intersect_shape(query, 1).is_empty():
				_grid.set_point_solid(Vector2i(x, y))

# Where to walk next, from `from` towards `to` (room-local feet positions).
func next_waypoint(from: Vector2, to: Vector2) -> Vector2:
	if is_clear_line(from, to):
		return to
	var start: Variant = _open_near(_cell_of(from))
	var goal: Variant = _open_near(_cell_of(to))
	if start == null || goal == null:
		return to
	var path := _grid.get_point_path(start, goal)
	if path.is_empty():
		return to
	# The furthest point along the path it can head straight for, skipping corners.
	for i in range(path.size() - 1, 0, -1):
		if is_clear_line(from, path[i]):
			return path[i]
	return path[mini(1, path.size() - 1)]

func is_open(point: Vector2) -> bool:
	var cell := _cell_of(point)
	return _region.has_point(cell) && !_grid.is_point_solid(cell)

# True when feet could walk straight from `from` to `to` without crossing a blocked cell.
func is_clear_line(from: Vector2, to: Vector2) -> bool:
	var along := to - from
	var length := along.length()
	var side := Vector2.ZERO if length == 0 else along.orthogonal() / length * FEET_HALF_WIDTH
	var steps := maxi(1, ceili(length / LINE_STEP))
	for i in range(steps + 1):
		var point := from + along * (float(i) / steps)
		for offset in [Vector2.ZERO, side, -side]:
			if !is_open(point + offset):
				return false
	return true

# `point` if it's on open floor, otherwise the centre of the nearest open cell, or null if
# the whole floor is blocked.
func nearest_open(point: Vector2) -> Variant:
	if is_open(point):
		return point
	var cell: Variant = _open_near(_cell_of(point), maxi(_region.size.x, _region.size.y))
	return null if cell == null else _cell_centre(cell)

func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / Room.CELL_SIZE).floor())

func _cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Room.CELL_SIZE

# `cell` if it's open floor, otherwise the nearest open cell (an enemy brushing a pit edge,
# or a target over a rock), or null if there's none close by.
func _open_near(cell: Vector2i, max_radius := 3) -> Variant:
	for radius in range(0, max_radius + 1):
		var best: Variant = null
		var best_distance := INF
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var c := Vector2i(x, y)
				if maxi(absi(x - cell.x), absi(y - cell.y)) != radius:
					continue
				if !_region.has_point(c) || _grid.is_point_solid(c):
					continue
				var distance := Vector2(c - cell).length()
				if distance < best_distance:
					best = c
					best_distance = distance
		if best != null:
			return best
	return null
