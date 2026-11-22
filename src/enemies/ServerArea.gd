class_name ServerArea
extends Node2D

# The area a server (see Server) covers, drawn on its room's floor: a faint tint of its
# boost's colour, edged with a ring of chunky pixels for a circle, or over the whole floor
# for a server that covers its room. Lives on the room rather than the server so it isn't
# scaled with it, and goes with the server when it breaks.

const PIXEL := 2.0 # World pixels per block of the ring and fill: 5 screen pixels at the rooms' 2.5x zoom
const FILL_ALPHA := 0.1
const RING_ALPHA := 0.45

var server: Server
var _color := Color.TRANSPARENT # Colour last drawn, to redraw only when it changes

func _ready() -> void:
	# Just before the room's first enemy: after its tile layers (some floor tiles draw at z
	# 0, so later siblings at 0 go over them) but under everyone standing on the floor.
	var room := get_parent()
	for child in room.get_children():
		if child is Enemy:
			room.move_child(self, child.get_index())
			return

func _process(_delta: float) -> void:
	if !is_instance_valid(server):
		queue_free()
		return
	var color := server.area_color()
	if color != _color:
		_color = color
		queue_redraw()

func _draw() -> void:
	var room := get_parent() as Room
	if room == null || !is_instance_valid(server):
		return
	var fill := Color(_color, FILL_ALPHA)
	if server.whole_room:
		draw_rect(room.floor_rect, fill)
		return
	var ring := Color(_color, RING_ALPHA)
	for piece: Array in disc_rows(server.position, server.radius):
		var rect := (piece[0] as Rect2).intersection(room.floor_rect)
		if rect.has_area():
			draw_rect(rect, ring if piece[1] else fill)

# The pixelated disc of `radius` round `centre`, as rects on a PIXEL grid, one row of blocks
# at a time: [Rect2, true for the ring round the edge or false for the inside]. The ring is
# one block thick and joins up all the way round.
static func disc_rows(centre: Vector2, radius: float) -> Array[Array]:
	var pieces: Array[Array] = []
	if radius < PIXEL:
		return pieces
	var rows := ceili(radius / PIXEL)
	for row in range(-rows, rows):
		# Middle of this row of blocks, measured from the centre.
		var y := (row + 0.5) * PIXEL
		var outer := _half_width(radius, y)
		if outer <= 0:
			continue
		# The ring reaches as far in as the rows either side of it reach out, so it has no gaps
		# where the edge runs steeply.
		var inner := minf(_half_width(radius - PIXEL, y), minf(
			_half_width(radius, y - PIXEL), _half_width(radius, y + PIXEL)))
		inner = minf(inner, outer - PIXEL) # At least a block of ring each side
		var top := centre.y + row * PIXEL
		if inner <= 0:
			pieces.append([Rect2(centre.x - outer, top, outer * 2, PIXEL), true])
			continue
		pieces.append([Rect2(centre.x - outer, top, outer - inner, PIXEL), true])
		pieces.append([Rect2(centre.x + inner, top, outer - inner, PIXEL), true])
		pieces.append([Rect2(centre.x - inner, top, inner * 2, PIXEL), false])
	return pieces

# Half the width, in whole blocks, of a disc of `radius` at height `y` from its middle.
static func _half_width(radius: float, y: float) -> float:
	if radius <= 0 || absf(y) >= radius:
		return 0.0
	return floorf(sqrt(radius * radius - y * y) / PIXEL) * PIXEL
