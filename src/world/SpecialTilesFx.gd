class_name SpecialTilesFx
extends Node2D

# The little animations over a room's special tiles: sparks running round teleporters,
# glints over ice and paste bubbling (faster while it holds someone); plus dust falling
# into cracked floor. Wires, spikes, cracked floor, a live plate and the slow and fast tiles have
# hand-drawn animation frames instead (SpecialTiles.ANIMATIONS and _frame_for). Drawn in
# code, on whole pixels, each tile's timing offset by its own seed so a room of them
# doesn't move in step.
#
# SpecialTiles makes one as its child while its rules run (in a room, with the player in it)
# and calls step() every physics frame. It only reads the layer's tile states.

const AMBIENT_DUST_CHANCE := 3.0 # Per second, per hole or cracking floor: dust falling in
const BUBBLE := Color("f7b866")

var layer: SpecialTiles
var _time := 0.0

func _ready() -> void:
	z_index = 1 # Over the tiles, under the player

# Moves the animations on a frame and throws the odd spark or speck of dust.
func step(delta: float) -> void:
	_time = layer.clock()
	_ambient_effects(delta)
	queue_redraw()

func _draw() -> void:
	for cell in layer.painted_cells():
		var tile := layer.tile_state(cell)
		var origin := Vector2(cell) * Room.CELL_SIZE
		var seed := _seed(cell)
		match tile.frame:
			SpecialTiles.Frame.TELEPORT_1, SpecialTiles.Frame.TELEPORT_2, \
					SpecialTiles.Frame.TELEPORT_3, SpecialTiles.Frame.TELEPORT_4:
				_teleport(origin, seed, SpecialTiles.teleport_colour(tile.frame))
			SpecialTiles.Frame.SLICK: _glint(origin, seed)
			SpecialTiles.Frame.PASTE: _bubbles(origin, seed, cell)

func _pixel(at: Vector2, colour: Color) -> void:
	draw_rect(Rect2(at.floor(), Vector2.ONE), colour)

# Three sparks running round the ring, and the middle breathing.
func _teleport(origin: Vector2, seed: float, colour: Color) -> void:
	var centre := origin + Vector2.ONE * 12
	draw_circle(centre, 6.5, Color(colour, 0.1 + 0.08 * sin(_time * 3.0 + seed * TAU)))
	for k in 3:
		var angle := _time * 2.5 + k * TAU / 3.0 + seed * TAU
		_pixel(centre + Vector2.from_angle(angle) * 9.5, colour.lightened(0.6))

# Every few seconds a glint runs diagonally over the ice.
func _glint(origin: Vector2, seed: float) -> void:
	var period := 2.6
	var t := fmod(_time + seed * period, period) / 0.45
	if t >= 1.0:
		return
	var along := -4.0 + t * 30.0
	for i in 5:
		var at := Vector2(along + i, 20 - i * 1.2 - t * 14.0)
		if at.x >= 1 && at.x < 23 && at.y >= 1 && at.y < 23:
			_pixel(origin + at, Color(1, 1, 1, 0.8))

# Two bubbles slowly swelling and popping, faster while it holds someone.
func _bubbles(origin: Vector2, seed: float, cell: Vector2i) -> void:
	var speed := 1.6 if layer.is_holding_at(cell) else 0.7
	for k in 2:
		var t := fmod(_time * speed + seed + k * 0.5, 1.0)
		var at := origin + Vector2(7 + k * 9 + int(seed * 4.0), 8 + k * 7)
		if t < 0.85:
			draw_arc(at, 0.5 + t * 1.8, 0, TAU, 8, BUBBLE, 1.0)
		else:
			for d: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2)]:
				_pixel(at + d, Color(1, 0.85, 0.6, 0.8))

# Dust trickling into holes and floor that's giving way.
func _ambient_effects(delta: float) -> void:
	for cell in layer.painted_cells():
		var tile := layer.tile_state(cell)
		var corner := Vector2(cell) * Room.CELL_SIZE
		if tile.frame == SpecialTiles.Frame.CRACKED \
				&& tile.phase in [SpecialTiles.Phase.WARNING, SpecialTiles.Phase.LIVE] \
				&& randf() < AMBIENT_DUST_CHANCE * delta:
			var edge := Vector2(randf_range(4, 20), randf_range(4, 20))
			Juice.burst(layer, layer.to_global(corner + edge), SpecialTiles.DUST, 1, 12.0,
				(Vector2.ONE * 12 - edge).normalized(), 1.0, 0.3)

# A steady number from 0 to 1 for `cell`, so each tile's animation runs to its own time.
func _seed(cell: Vector2i) -> float:
	return float(absi(hash(cell)) % 1000) / 1000.0
