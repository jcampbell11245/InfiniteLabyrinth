extends Control

# Bottom-right minimap, drawn as a chunky 8-bit dot-matrix display: one square dot per room
# on a translucent dark backing that hugs the rooms, so the start and end rooms stick out
# either side of the grid. Unvisited rooms' dots are dim; the start and end rooms' are
# always lit green, so the player knows where they're heading; every other room's dot lights
# up once the player has been in it, yellow for a key room and blue for the rest. A key
# room found by a metal detector (Items) lights yellow before the player gets there. A room
# with a premium (silver) server standing in it is silver from the start, whatever it is. A red
# outline round the current room's dot flashes. The boss room isn't shown.
#
# It's painted pixel by pixel into a small image and drawn PIXEL times bigger with no
# filtering, so every edge lands on the same chunky pixel grid as the rest of the HUD art
# (HudLayer draws its sprites 5x). The backing gets a black outer line and a grey inner
# one, with its corners notched off.
#
# Rooms are placed by where they sit in the world, not by id, so the room creator's single
# test room lands in the right cell too. Visited rooms are remembered per floor: the
# Overworld, and this HUD with it, is reloaded for every new floor.

const PIXEL := 5 # Screen pixels per art pixel, matching HudLayer's scale
const CELL := 5 # Art pixels from one room's dot to the next
const DOT := 3 # Art pixels across each dot; the outline goes in the gap round it
const PAD := 2 # Art pixels of backing past the outermost cells, inside the border
const SCREEN_MARGIN := Vector2(40, 40) # From the bottom-right corner of the screen
const FLASH_TIME := 0.35 # Seconds the outline spends on, then off

const BACKING := Color(0.1, 0.1, 0.12, 0.7)
const BORDER := Color8(124, 124, 124) # Grey rim
const OUTER := Color8(0, 0, 0)
const UNLIT := Color8(64, 64, 72)
const LANDMARK := Color8(88, 216, 84) # Start and end rooms
const VISITED := Color8(60, 188, 252)
const KEY_ROOM := Color8(248, 184, 0) # Visited key rooms
# Rooms with a premium (silver) server standing (see Server), lit from the start of the floor so
# the player can hunt them down. Silver, a colour no other room uses, so it stands out.
const FLOOR_SERVER := Color8(222, 230, 242)
const CURRENT_OUTLINE := Color8(248, 56, 0)
const SHINE := 0.45 # How far towards white a lit dot's top-left pixel is

var _visited := {} # Room id -> true
var _cells := {} # Room id -> Vector2i grid cell, from the room's world position
var _key_rooms := {} # Room id -> true, for rooms built from a key room scene
var _marked := {} # Room id -> true, for key rooms a metal detector has shown (Items)
var _origin_cell := Vector2i.ZERO # Top-left cell of the box round every room
var _frame: Image # The backing and border, painted once the floor is laid out
var _texture := ImageTexture.new()
var _current := -1
var _flash_on := true
var _flash_left := FLASH_TIME

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Game.room_entered.connect(_on_room_entered)
	Game.room_marked.connect(_on_room_marked)

func _process(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0:
		_flash_left = FLASH_TIME
		_flash_on = !_flash_on
		_repaint()

func _on_room_entered(id: int) -> void:
	if _cells.is_empty():
		_lay_out()
	_visited[id] = true
	_current = id
	_flash_on = true # Show the new room's outline straight away
	_flash_left = FLASH_TIME
	_repaint()

func _on_room_marked(id: int) -> void:
	_marked[id] = true
	_repaint()

# Works out each room's cell from its position, sizes the minimap to fit them all and
# paints the backing. Done on the first room entered, once the Overworld has built the floor.
func _lay_out() -> void:
	if Game.overworld == null:
		return
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for id: int in Game.overworld.rooms_by_id:
		if id == Constants.BOSS_ROOM:
			continue
		var room: Room = Game.overworld.rooms_by_id[id]
		var cell := Vector2i(((room.position - Overworld.GRID_ORIGIN) / Constants.ROOM_SIZE).round())
		_cells[id] = cell
		if room.is_key_room():
			_key_rooms[id] = true
		low = low.min(cell)
		high = high.max(cell)
	if _cells.is_empty():
		return
	_origin_cell = low
	# The outer line takes an art pixel on every side; the grey border is the backing's own edge.
	var art_size := (high - low + Vector2i.ONE) * CELL + Vector2i.ONE * (PAD + 1) * 2
	_frame = _paint_frame(art_size)
	size = Vector2(art_size * PIXEL)
	position = get_viewport_rect().size - size - SCREEN_MARGIN

# The backing: a padded square behind every room, merged, its convex corners notched off,
# then edged grey inside and black outside.
func _paint_frame(art_size: Vector2i) -> Image:
	var inside := {} # Vector2i art pixel -> true
	for id: int in _cells:
		@warning_ignore("integer_division")
		var corner := _dot_corner(id) - Vector2i.ONE * ((CELL - DOT) / 2 + PAD)
		for y in range(CELL + PAD * 2):
			for x in range(CELL + PAD * 2):
				inside[corner + Vector2i(x, y)] = true
	var corners: Array[Vector2i] = [] # Found first, so notching one doesn't expose the next
	for pixel: Vector2i in inside:
		var open_x := !inside.has(pixel + Vector2i.LEFT) || !inside.has(pixel + Vector2i.RIGHT)
		var open_y := !inside.has(pixel + Vector2i.UP) || !inside.has(pixel + Vector2i.DOWN)
		if open_x && open_y:
			corners.append(pixel)
	for pixel in corners:
		inside.erase(pixel)

	var image := Image.create(art_size.x, art_size.y, false, Image.FORMAT_RGBA8)
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for pixel: Vector2i in inside:
		var edge := false
		for side in sides:
			if !inside.has(pixel + side):
				edge = true
				var out := pixel + side
				if Rect2i(Vector2i.ZERO, art_size).has_point(out):
					image.set_pixelv(out, OUTER)
		image.set_pixelv(pixel, BORDER if edge else BACKING)
	return image

# Repaints the dots and outline over the frame and uploads the result.
func _repaint() -> void:
	if _frame == null:
		return
	var image := _frame.duplicate() as Image
	var premium := _floor_server_rooms()
	for id: int in _cells:
		var color := FLOOR_SERVER if premium.has(id) else _room_color(id)
		var corner := _dot_corner(id)
		image.fill_rect(Rect2i(corner, Vector2i.ONE * DOT), color)
		if color != UNLIT:
			image.set_pixelv(corner, color.lerp(Color.WHITE, SHINE))
	if _flash_on && _cells.has(_current):
		var ring := Rect2i(_dot_corner(_current) - Vector2i.ONE, Vector2i.ONE * (DOT + 2))
		for x in range(ring.position.x, ring.end.x):
			image.set_pixel(x, ring.position.y, CURRENT_OUTLINE)
			image.set_pixel(x, ring.end.y - 1, CURRENT_OUTLINE)
		for y in range(ring.position.y, ring.end.y):
			image.set_pixel(ring.position.x, y, CURRENT_OUTLINE)
			image.set_pixel(ring.end.x - 1, y, CURRENT_OUTLINE)
	_texture.set_image(image)
	queue_redraw()

func _draw() -> void:
	if _frame != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)

# Green for the start and end rooms; once visited, yellow for key rooms and blue for the
# rest; dim otherwise. A key room a metal detector found is yellow before it's visited.
func _room_color(id: int) -> Color:
	if id == Constants.START_ROOM || id == Constants.END_ROOM:
		return LANDMARK
	if _marked.has(id):
		return KEY_ROOM
	if !_visited.has(id):
		return UNLIT
	return KEY_ROOM if _key_rooms.has(id) else VISITED

# Ids of the rooms with a premium server still standing. Read at every repaint (the
# outline's flashing repaints often), so a room goes back to normal soon after its last
# one breaks.
func _floor_server_rooms() -> Dictionary:
	var ids := {}
	for node in get_tree().get_nodes_in_group(Server.FLOOR_GROUP):
		var server := node as Server
		if server != null && !server.is_queued_for_deletion() && server.room != null:
			ids[server.room.room_id] = true
	return ids

# Top-left art pixel of a room's dot.
func _dot_corner(id: int) -> Vector2i:
	var cell: Vector2i = _cells[id] - _origin_cell
	@warning_ignore("integer_division")
	return Vector2i.ONE * (PAD + 1 + (CELL - DOT) / 2) + cell * CELL
