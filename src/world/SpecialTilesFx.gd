class_name SpecialTilesFx
extends Node2D

# The little animations over a room's special tiles: sparks running round teleporters, a
# light sweep over speed tiles, sand trickling on slow tiles, glints over ice and spike
# tips, copper flickering on resting wires and current flickering when live, cracked floor
# darkening as it gives way, and paste bubbling (faster while it holds someone); plus stray
# sparks and falling dust. Drawn in code, on whole pixels, each tile's timing offset by its
# own seed so a room of them doesn't move in step.
#
# SpecialTiles makes one as its child while its rules run (in a room, with the player in it)
# and calls step() every physics frame. It only reads the layer's tile states.

const SPIKE_TIPS: Array[Vector2i] = [ # Spike points in the spikes art
	Vector2i(5, 4), Vector2i(12, 4), Vector2i(19, 4), Vector2i(5, 11), Vector2i(12, 11),
	Vector2i(19, 11), Vector2i(5, 18), Vector2i(12, 18), Vector2i(19, 18)]
const WIRE_GAPS: Array[Vector2i] = [Vector2i(11, 8), Vector2i(12, 16)] # Bare copper in the wires art
const AMBIENT_SPARK_CHANCE := 0.25 # Per second, per resting wire: a stray spark
const AMBIENT_DUST_CHANCE := 3.0 # Per second, per hole or cracking floor: dust falling in
const SAND := Color("e6d38a")
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
			SpecialTiles.Frame.FAST: _sweep(origin, seed, 34.0, Color(1, 0.95, 0.7, 0.35))
			SpecialTiles.Frame.SLOW: _slow(origin, seed)
			SpecialTiles.Frame.SLICK: _glint(origin, seed)
			SpecialTiles.Frame.SPIKES: _spike_glint(origin, seed, cell)
			SpecialTiles.Frame.WIRES, SpecialTiles.Frame.PLATE: _current(origin, seed, tile)
			SpecialTiles.Frame.CRACKED: _giving_way(origin, tile)
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

# A band of light sliding across the tile, left to right.
func _sweep(origin: Vector2, seed: float, speed: float, colour: Color) -> void:
	var x := fmod(_time * speed + seed * 24.0, 30.0) - 3.0
	var left := clampf(x, 3.0, 21.0)
	var right := clampf(x + 3.0, 3.0, 21.0)
	if right > left:
		draw_rect(Rect2(origin + Vector2(left, 3), Vector2(right - left, 18)), colour)

# Sand trickling through the hourglass, and the tile slowly breathing.
func _slow(origin: Vector2, seed: float) -> void:
	draw_rect(Rect2(origin + Vector2(3, 3), Vector2(18, 18)),
		Color(0.6, 0.55, 1.0, 0.06 + 0.06 * sin(_time * 1.5 + seed * TAU)))
	var fall := fmod(_time * 0.9 + seed, 1.0)
	_pixel(origin + Vector2(11, 12 + fall * 4.0), SAND)

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

# Now and then one spike tip catches the light.
func _spike_glint(origin: Vector2, seed: float, cell: Vector2i) -> void:
	var period := 1.7
	var step_number := floori((_time + seed * 5.0) / period)
	var t := fmod(_time + seed * 5.0, period) / period
	if t > 0.25:
		return
	var tip := SPIKE_TIPS[absi(hash(Vector2i(step_number, 0) + cell)) % SPIKE_TIPS.size()]
	var strength := sin(t / 0.25 * PI)
	var at := origin + Vector2(tip)
	_pixel(at, Color(1, 1, 1, strength))
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_pixel(at + d, Color(1, 1, 1, strength * 0.5))

# Live wires or a live plate flicker with current; resting wires' bare copper glows now
# and then.
func _current(origin: Vector2, seed: float, tile: Dictionary) -> void:
	if tile.phase == SpecialTiles.Phase.LIVE:
		draw_rect(Rect2(origin, Vector2.ONE * Room.CELL_SIZE),
			Color(SpecialTiles.SHOCK_COLOR, 0.12 + 0.18 * absf(sin(_time * 37.0 + seed * 9.0))))
	elif tile.frame == SpecialTiles.Frame.WIRES && tile.phase == SpecialTiles.Phase.RESTING:
		var flicker := sin(_time * 11.0 + seed * 20.0) * sin(_time * 4.3 + seed * 7.0)
		if flicker > 0.6:
			for gap in WIRE_GAPS:
				_pixel(origin + Vector2(gap), Color(1.0, 0.9, 0.5, (flicker - 0.6) * 2.5))

# Cracked floor darkens as it gives way.
func _giving_way(origin: Vector2, tile: Dictionary) -> void:
	if tile.phase == SpecialTiles.Phase.WARNING:
		var progress: float = 1.0 - tile.left / maxf(Tuning.crack_time, 0.01)
		draw_circle(origin + Vector2.ONE * 12, 3.0 + 7.0 * progress, Color(0, 0, 0, 0.35 * progress))

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

# Stray sparks off resting wires, dust trickling into holes and floor that's giving way.
func _ambient_effects(delta: float) -> void:
	for cell in layer.painted_cells():
		var tile := layer.tile_state(cell)
		var corner := Vector2(cell) * Room.CELL_SIZE
		if tile.frame == SpecialTiles.Frame.WIRES && tile.phase == SpecialTiles.Phase.RESTING \
				&& randf() < AMBIENT_SPARK_CHANCE * delta:
			var gap := WIRE_GAPS.pick_random() as Vector2i
			Juice.burst(layer, layer.to_global(corner + Vector2(gap)), SpecialTiles.SPARK_COLOR, 2, 30.0,
				Vector2.UP, 1.0, 0.15)
		elif tile.frame == SpecialTiles.Frame.CRACKED \
				&& tile.phase in [SpecialTiles.Phase.WARNING, SpecialTiles.Phase.LIVE] \
				&& randf() < AMBIENT_DUST_CHANCE * delta:
			var edge := Vector2(randf_range(4, 20), randf_range(4, 20))
			Juice.burst(layer, layer.to_global(corner + edge), SpecialTiles.DUST, 1, 12.0,
				(Vector2.ONE * 12 - edge).normalized(), 1.0, 0.3)

# A steady number from 0 to 1 for `cell`, so each tile's animation runs to its own time.
func _seed(cell: Vector2i) -> float:
	return float(absi(hash(cell)) % 1000) / 1000.0
