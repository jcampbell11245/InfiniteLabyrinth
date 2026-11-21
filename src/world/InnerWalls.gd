class_name InnerWalls
extends RefCounted

# Which piece of inner wall art each wall cell is drawn with, and the tool that makes the
# pieces the hand-drawn sheet doesn't have.
#
# The hand-drawn sheet (SOURCE) has 16 pieces, one per set of side neighbours (a mask of
# 1 top, 2 right, 4 bottom, 8 left, as BASE_ATLAS lays them out). Those assume that where
# two sides join, the diagonal between them is wall too. Where it's floor (an inside
# corner, as in an L, T or plus), the piece needs that corner cut in: build_image() makes
# a piece for every such case by pasting quarters of the 16 together, and puts them below
# the 16 in JOINED, the sheet the game draws with. Run tools/build_inner_walls.gd after
# changing SOURCE.
#
# Each piece splits into four quarters at the middle column and at row 10, where a wall
# with nothing below turns from its top into its front face. A quarter's look depends on
# its two sides and, when both are wall, the diagonal between them.

const SOURCE := "res://assets/sprites/tileset/inner_walls/inner_walls.png"
const JOINED := "res://assets/sprites/tileset/inner_walls/inner_walls_joined.png"
const COLUMNS := 4
const BASE_ROWS := 4 # Rows of SOURCE; the made pieces start below them
const SIZE := 24 # Pixels per piece
const SPLIT := Vector2i(12, 10) # Where the quarters meet, in a piece's pixels
const BORDER := 3 # Pixels of edge drawn round an inside corner of the top

# Hand-drawn piece for each set of side neighbours: a one-high strip along the top of the
# sheet, a 3x3 block below it and a one-wide column on the right.
const BASE_ATLAS := {
	2: Vector2i(0, 0), 10: Vector2i(1, 0), 8: Vector2i(2, 0), 0: Vector2i(3, 0),
	6: Vector2i(0, 1), 14: Vector2i(1, 1), 12: Vector2i(2, 1), 4: Vector2i(3, 1),
	7: Vector2i(0, 2), 15: Vector2i(1, 2), 13: Vector2i(2, 2), 5: Vector2i(3, 2),
	3: Vector2i(0, 3), 11: Vector2i(1, 3), 9: Vector2i(2, 3), 1: Vector2i(3, 3),
}
const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8
# The corners, in the order of the bits of an inside-corner mask: top-left, top-right,
# bottom-right, bottom-left. Each has the two sides that meet there and its diagonal.
const CORNER_SIDES: Array[int] = [TOP | LEFT, TOP | RIGHT, BOTTOM | RIGHT, BOTTOM | LEFT]
const CORNER_DIAGONALS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
# The side neighbours, in the order of the side mask's bits (as RoomDesign.NEIGHBOURS; kept
# here so the sheet tool doesn't load the game's scripts).
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static var _extra_index := {} # side mask * 16 + inside-corner mask -> index of the made piece

# The atlas cell to draw `cell` with, given `is_wall` (Vector2i -> bool) for its neighbours.
static func atlas_cell(cell: Vector2i, is_wall: Callable) -> Vector2i:
	var sides := 0
	for i in SIDES.size():
		if is_wall.call(cell + SIDES[i]):
			sides |= 1 << i
	var inside := 0
	for i in CORNER_SIDES.size():
		if sides & CORNER_SIDES[i] == CORNER_SIDES[i] && !is_wall.call(cell + CORNER_DIAGONALS[i]):
			inside |= 1 << i
	return atlas_for(sides, inside)

# The piece for side mask `sides` with the corners in `inside` cut in.
static func atlas_for(sides: int, inside: int) -> Vector2i:
	if inside == 0:
		return BASE_ATLAS[sides]
	var index: int = _extras_index()[sides * 16 + inside]
	return Vector2i(index % COLUMNS, BASE_ROWS + index / COLUMNS)

# Every [side mask, inside-corner mask] with a corner cut in, in sheet order: a corner can
# only be cut in where both its sides are wall.
static func extras() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for sides in 16:
		var possible := 0
		for i in CORNER_SIDES.size():
			if sides & CORNER_SIDES[i] == CORNER_SIDES[i]:
				possible |= 1 << i
		for inside in range(1, 16):
			if inside & ~possible == 0:
				list.append(Vector2i(sides, inside))
	return list

static func _extras_index() -> Dictionary:
	if _extra_index.is_empty():
		var list := extras()
		for i in list.size():
			_extra_index[list[i].x * 16 + list[i].y] = i
	return _extra_index

static func rows() -> int:
	return BASE_ROWS + ceili(extras().size() / float(COLUMNS))

# --- Making the sheet ---

# JOINED from the hand-drawn `source`: the 16 pieces as they are, then the made ones.
static func build_image(source: Image) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	var out := Image.create(COLUMNS * SIZE, rows() * SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(source, Rect2i(0, 0, COLUMNS * SIZE, BASE_ROWS * SIZE), Vector2i.ZERO)
	var list := extras()
	for i in list.size():
		var piece := _made_piece(source, list[i].x, list[i].y)
		out.blit_rect(piece, Rect2i(0, 0, SIZE, SIZE), Vector2i(i % COLUMNS, BASE_ROWS + i / COLUMNS) * SIZE)
	return out

static func _piece(source: Image, sides: int) -> Image:
	return source.get_region(Rect2i(BASE_ATLAS[sides] * SIZE, Vector2i.ONE * SIZE))

# The piece for `sides`, with each corner in `inside` cut in.
static func _made_piece(source: Image, sides: int, inside: int) -> Image:
	var piece := _piece(source, sides)
	for i in CORNER_SIDES.size():
		if inside & (1 << i) == 0:
			continue
		var vertical := CORNER_SIDES[i] & (TOP | BOTTOM)
		var horizontal := CORNER_SIDES[i] & (LEFT | RIGHT)
		if vertical == TOP:
			# On the top: the edges of the walls above and beside run on into this one and
			# meet at the corner, so take the corner's few pixels from the pieces with
			# those edges showing.
			var x0 := 0 if horizontal == LEFT else SIZE - BORDER
			_paste_corner(piece, _piece(source, sides & ~TOP), _piece(source, sides & ~horizontal),
				Rect2i(x0, 0, BORDER, BORDER))
		else:
			# By the front face: the wall beside shows its face here (there's nothing under
			# it), so this one shows its side edge down to the wall below.
			var x0 := 0 if horizontal == LEFT else SPLIT.x
			var quarter := Rect2i(x0, SPLIT.y, SPLIT.x, SIZE - SPLIT.y)
			piece.blit_rect(_piece(source, sides & ~horizontal), quarter, quarter.position)
	return piece

# Over `rect` of `piece`, each pixel that's edge in `top_edge` or `side_edge` (differs
# from `piece`, which is plain top there) is taken from it.
static func _paste_corner(piece: Image, top_edge: Image, side_edge: Image, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var plain := piece.get_pixel(x, y)
			var from_top := top_edge.get_pixel(x, y)
			var from_side := side_edge.get_pixel(x, y)
			if from_top != plain:
				piece.set_pixel(x, y, from_top)
			elif from_side != plain:
				piece.set_pixel(x, y, from_side)
