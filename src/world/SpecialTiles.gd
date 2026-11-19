class_name SpecialTiles
extends TileMap

# The room's special floor tiles (traps, movement tiles and teleporters), painted on a
# TileMap layer of their own named "SpecialTiles" above the floor. Each painted cell's atlas
# column is a Frame; what it was painted with is the tile's kind, and the script swaps the
# frame as the tile changes state (wires sparking, a plate pressed, a floor cracking).
#
# The same layer is the room creator's preview of a design and, in a room, runs the rules.
# The rules only run under a Room (the room creator's preview has its room script taken
# off), and only while the player is in that room. It runs after the player and enemies
# have moved each physics frame (process_physics_priority), then looks at whose feet are on
# which cell:
#
#   Wires     cycle: resting, sparking (the warning), live (shocks whoever is on them).
#   Plate     is stepped on, clicks down, then goes live like wires, then re-arms.
#             Swinging the sword into live wires or a live plate breaks it for good. Both
#             twinkle as they go live, as an enemy does when its parry window opens.
#   Spikes    hurt on stepping on, and again every Tuning.spike_interval while stood on.
#   Cracked   cracks when stood on, then opens into a pit, then mends.
#   Paste     holds whoever steps in within Tuning.paste_reach of its edge, pulling them back
#             when they stop; the player rolls out. It dissolves Tuning.paste_dissolve_time
#             after first catching someone, and a bar over whoever it holds counts that down
#             (paste_left). It squelches on catching, creaks when pulled against, and snaps
#             as it pulls back.
#   Slick, Slow, Fast   change how things move while on them; the player and enemies ask
#             speed_factor() and is_slick() themselves.
#   Teleport  sends whoever steps on it, and any projectile flying over it, to the next
#             square of the same colour and symbol. It works from TELEPORT_GRACE pixels
#             outside its square, so feet brushing its edge still go through. The square
#             the player would be sent to glows while they're within
#             Tuning.teleport_glow_range of one.
#
# The player's roll keeps them from harm (the hurtbox is off while rolling, as for hits),
# and rolling is the way out of paste. Enemies are hurt and moved the same way, but walk
# round the dangerous tiles when they can (RoomNav reads avoided_cells()).

# Atlas columns of assets/sprites/tiles/special_tiles.png.
enum Frame {
	WIRES, WIRES_SPARK, WIRES_LIVE, WIRES_BROKEN,
	SPIKES,
	CRACKED, CRACKING, HOLE,
	SLICK,
	PLATE, PLATE_DOWN, PLATE_LIVE, PLATE_BROKEN,
	PASTE,
	SLOW, FAST,
	TELEPORT_1, TELEPORT_2, TELEPORT_3, TELEPORT_4,
}
const TEXTURE := preload("res://assets/sprites/tiles/special_tiles.png")
const NODE_NAME := "SpecialTiles"
const SCENE := "res://src/world/tiles/SpecialTiles.tscn"
const TELEPORT_PAIRS := 4

# Tile states.
enum Phase { RESTING, WARNING, LIVE, BROKEN }

# Sword clashes: points ahead of the player's feet, in pixels, whose cells the swing reaches.
const SWORD_REACH: Array[float] = [6.0, 18.0]
const HOLE_INSET := 3.0 # Pixels the hole's fall area stops short of each side of its cell
const SHOCK_COLOR := Color(0.62, 0.91, 1.0)
const SPARK_COLOR := Color(1.0, 0.95, 0.6)
const SPARK_CHANCE := 8.0 # Per second, per sparking tile: a few sparks fly as a warning
const DUST := Color(0.6, 0.52, 0.45)
const PASTE_COLOR := Color(0.85, 0.5, 0.17)
const MOVING_SPEED := 5.0 # Pixels/sec below which something caught in paste counts as still
const SHOCK_SOUND := preload("res://assets/sfx/laser_unlock.wav")
const SHOCK_DB := -10.0
const SHOCK_PITCH := 1.8
const CRUMBLE_SOUND := preload("res://assets/sfx/rumble1.wav")
const CRUMBLE_DB := -8.0
const TELEPORT_SOUND := preload("res://assets/sfx/magic1.wav")
const TELEPORT_DB := -8.0
const PASTE_STICK_SOUND := preload("res://assets/sfx/paste_stick.wav")
const PASTE_STRETCH_SOUND := preload("res://assets/sfx/paste_stretch.wav")
const PASTE_SNAP_SOUND := preload("res://assets/sfx/paste_snap.wav")
const PASTE_DB := -6.0
# Pulled back from at least this far past the paste's middle, the snap back is heard.
const PASTE_SNAP_DISTANCE := 10.0
const TELEPORT_GRACE := 5.0 # Pixels outside its square a teleporter still takes feet from
# Projectiles fly at about chest height; this far below one is the floor it's over.
const PROJECTILE_DROP := Vector2(0, 12)
const PROJECTILE_SPAN_STEPS := 3 # Points checked from the shot down to the floor under it, less one
const PROJECTILE_GRACE := 3.0 # Pixels outside a teleporter's square a shot still counts as over it
const PROJECTILE_GROUP := &"projectiles" # Every Projectile joins it (Projectile._ready)
const GLOW_PULSE := 7.0 # Radians/sec the destination glow pulses at
const GLOW_ALPHA := Vector2(0.6, 1.0) # Its least and most strength
# Over 1, so the art added on top of itself washes out towards white.
const GLOW_BRIGHTNESS := 2.5
const TWINKLE_OFFSET := Vector2(0, -4) # From a trap's centre to where its twinkle shows

var _room: Room
# Cell -> {frame: Frame it was painted with, phase: Phase, left: seconds in the phase,
# cycle: times it has gone live (wires, plates), dissolve_at: paste only}.
var _tiles := {}
var _holes := {} # Cell -> StaticBody2D on the pitfall layer, its shape on while the hole is open
var _bodies := {} # Instance id -> per-body record (see _record)
var _time := 0.0
var _clashed_swing := -1 # Player.swing_started_frame of the swing that last broke a tile
var _sounds := {}
var _glow: Sprite2D # Brightens the teleporter the player would be sent to

# --- Looking things up (any body, room or not) ---

# The frame painted on `cell`, or -1.
func painted(cell: Vector2i) -> int:
	if _tiles.has(cell):
		return _tiles[cell].frame
	if get_cell_source_id(0, cell) == -1:
		return -1
	return get_cell_atlas_coords(0, cell).x

# What a body standing at `global_point` stands on: the SpecialTiles of the room it's in
# and the painted frame there, or -1 if nothing special.
static func frame_at(room: Node, global_point: Vector2) -> int:
	if room == null:
		return -1
	var layer := room.get_node_or_null(NODE_NAME) as SpecialTiles
	if layer == null:
		return -1
	var cell := layer.local_to_map(layer.to_local(global_point))
	if !layer._tiles.has(cell):
		return layer.painted(cell)
	var tile: Dictionary = layer._tiles[cell]
	if tile.frame == Frame.PASTE && tile.phase == Phase.BROKEN:
		return -1 # Dissolved
	return tile.frame

# Walk, roll and attack speed on `frame`, as a multiple of normal.
static func speed_factor(frame: int) -> float:
	match frame:
		Frame.SLOW: return Tuning.slow_tile_multiplier
		Frame.FAST: return Tuning.fast_tile_multiplier
	return 1.0

static func is_slick(frame: int) -> bool:
	return frame == Frame.SLICK

static func is_teleport(frame: int) -> bool:
	return frame >= Frame.TELEPORT_1 && frame <= Frame.TELEPORT_4

# The frames a tile can be painted with (its resting look).
static func painted_frames() -> Array[int]:
	return [Frame.WIRES, Frame.SPIKES, Frame.CRACKED, Frame.SLICK, Frame.PLATE, Frame.PASTE,
		Frame.SLOW, Frame.FAST, Frame.TELEPORT_1, Frame.TELEPORT_2, Frame.TELEPORT_3, Frame.TELEPORT_4]

# A picture of `frame`, for the room creator's tool buttons.
static func icon(frame: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = TEXTURE
	texture.region = Rect2(frame * Room.CELL_SIZE, 0, Room.CELL_SIZE, Room.CELL_SIZE)
	return texture

# The room's layer, made (empty) if it has none yet.
static func of(room: Node) -> SpecialTiles:
	var layer := room.get_node_or_null(NODE_NAME) as SpecialTiles
	if layer == null:
		layer = (load(SCENE) as PackedScene).instantiate()
		layer.name = NODE_NAME
		room.add_child(layer)
	return layer

# Cells enemies should keep off when they can: anything that hurts or holds them.
func avoided_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in get_used_cells(0):
		if _is_avoided(cell):
			cells.append(cell)
	return cells

# Cells the player shouldn't respawn on after a fall: anything but plain floor, slick,
# slow and fast tiles.
func is_safe(cell: Vector2i) -> bool:
	return painted(cell) in [-1, Frame.SLICK, Frame.SLOW, Frame.FAST]

# The cell is an open hole (cracked floor that gave way).
func is_hole(cell: Vector2i) -> bool:
	return _tiles.has(cell) && _tiles[cell].frame == Frame.CRACKED && _tiles[cell].phase == Phase.LIVE

func _is_avoided(cell: Vector2i) -> bool:
	var frame := painted(cell)
	if !(frame in [Frame.WIRES, Frame.SPIKES, Frame.CRACKED, Frame.PLATE, Frame.PASTE]):
		return false
	return !_tiles.has(cell) || _tiles[cell].phase != Phase.BROKEN || frame == Frame.CRACKED

# Where a body on `cell` gets sent: the next square, in reading order, painted with the
# same teleporter, or null if it has no partner.
func teleport_destination(cell: Vector2i) -> Variant:
	var frame := painted(cell)
	if !is_teleport(frame):
		return null
	var squares: Array[Vector2i] = []
	for other: Vector2i in get_used_cells(0):
		if painted(other) == frame:
			squares.append(other)
	if squares.size() < 2:
		return null
	squares.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y || (a.y == b.y && a.x < b.x))
	return squares[(squares.find(cell) + 1) % squares.size()]

# The teleporter that takes something at `global_point`: one whose square, grown by `grace`
# pixels, it's inside (its own cell's first), or null.
func teleporter_at(global_point: Vector2, grace := TELEPORT_GRACE) -> Variant:
	var local := to_local(global_point)
	var centre := local_to_map(local)
	if is_teleport(painted(centre)):
		return centre
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := centre + Vector2i(x, y)
			if is_teleport(painted(cell)) && _cell_rect(cell).grow(grace).has_point(local):
				return cell
	return null

# The nearest teleporter within `reach` pixels of `global_point` that has somewhere to send
# things, or null.
func teleporter_near(global_point: Vector2, reach: float) -> Variant:
	var local := to_local(global_point)
	var best: Variant = null
	var best_distance := INF
	for cell: Vector2i in get_used_cells(0):
		if !is_teleport(painted(cell)) || teleport_destination(cell) == null:
			continue
		# Measured to the square's edge, so the range is the same from every side.
		var rect := _cell_rect(cell)
		var distance := (local.clamp(rect.position, rect.end) - local).length()
		if distance <= reach && distance < best_distance:
			best = cell
			best_distance = distance
	return best

# The teleporter the destination glow is on, or null if it's off.
func glowing_teleporter() -> Variant:
	if _glow == null || !_glow.visible:
		return null
	return local_to_map(_glow.position)

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * Room.CELL_SIZE, Vector2.ONE * Room.CELL_SIZE)

# --- Running in a room ---

func _ready() -> void:
	_room = get_parent() as Room
	process_physics_priority = 10 # After the player and enemies have moved
	set_physics_process(_room != null)
	if _room == null:
		return
	for cell: Vector2i in get_used_cells(0):
		var frame := get_cell_atlas_coords(0, cell).x
		var tile := {frame = frame, phase = Phase.RESTING, left = 0.0, cycle = 0, dissolve_at = -1.0}
		if frame == Frame.WIRES: # Out of step with each other
			tile.left = randf_range(0.0, Tuning.wire_idle_time)
		_tiles[cell] = tile
		if frame == Frame.CRACKED:
			_add_hole_body(cell)
	_sounds = {
		"shock": _add_sound(SHOCK_SOUND, SHOCK_DB),
		"crumble": _add_sound(CRUMBLE_SOUND, CRUMBLE_DB),
		"teleport": _add_sound(TELEPORT_SOUND, TELEPORT_DB),
		"stick": _add_sound(PASTE_STICK_SOUND, PASTE_DB),
		"stretch": _add_sound(PASTE_STRETCH_SOUND, PASTE_DB),
		"snap": _add_sound(PASTE_SNAP_SOUND, PASTE_DB),
	}
	_glow = Sprite2D.new()
	_glow.texture = TEXTURE
	_glow.region_enabled = true
	_glow.z_index = 1 # Over the tiles, under the player
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD # Brightens towards white
	_glow.material = additive
	_glow.visible = false
	add_child(_glow)

func _add_sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	add_child(sound)
	return sound

# A body on the pitfall layer covering `cell`, off until the floor gives way. The player's
# FeetBox falls into it like any pit, and enemies' feet are stopped by it.
func _add_hole_body(cell: Vector2i) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * (Room.CELL_SIZE - HOLE_INSET * 2)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.disabled = true
	var body := StaticBody2D.new()
	body.collision_layer = 1 << (Constants.Layer.PITFALL - 1)
	body.collision_mask = 0
	body.position = map_to_local(cell)
	body.add_child(collision)
	add_child(body)
	_holes[cell] = collision

func _physics_process(delta: float) -> void:
	var player := Game.player
	if player == null || player.current_room != _room.room_id || player.in_transition:
		return
	_time += delta
	_check_clash(player)
	for cell: Vector2i in _tiles:
		_update_tile(cell, delta)
	var seen := {}
	if player.visible:
		_affect(player, player.global_position + Player.FEET, delta)
		seen[player.get_instance_id()] = true
	for child in _room.get_children():
		var enemy := child as Enemy
		if _affects(enemy):
			_affect(enemy, enemy.feet_position(), delta)
			seen[enemy.get_instance_id()] = true
	# Projectiles live on the room or the overworld; only those over this room's floor count.
	for node in get_tree().get_nodes_in_group(PROJECTILE_GROUP):
		var shot := node as Projectile
		if shot != null && !shot.is_queued_for_deletion() \
				&& _room.floor_rect.has_point(_room.to_local(shot.global_position + PROJECTILE_DROP)):
			_carry_projectile(shot)
			seen[shot.get_instance_id()] = true
	for id: int in _bodies.keys():
		if !seen.has(id):
			_bodies.erase(id)
	_update_glow(player)

# Lights up where the player would be sent from the teleporter they're nearest, if they're
# within Tuning.teleport_glow_range of one.
func _update_glow(player: Player) -> void:
	var near: Variant = teleporter_near(player.global_position + Player.FEET, Tuning.teleport_glow_range) \
		if player.visible else null
	if near == null:
		_glow.visible = false
		return
	var destination: Vector2i = teleport_destination(near)
	_glow.position = map_to_local(destination)
	_glow.region_rect = Rect2(painted(destination) * Room.CELL_SIZE, 0, Room.CELL_SIZE, Room.CELL_SIZE)
	var pulse := (sin(_time * GLOW_PULSE) + 1.0) / 2.0
	_glow.modulate = Color(GLOW_BRIGHTNESS, GLOW_BRIGHTNESS, GLOW_BRIGHTNESS,
		lerpf(GLOW_ALPHA.x, GLOW_ALPHA.y, pulse))
	_glow.visible = true

# --- Tile states ---

func _update_tile(cell: Vector2i, delta: float) -> void:
	var tile: Dictionary = _tiles[cell]
	match tile.frame:
		Frame.WIRES: _update_wires(cell, tile, delta)
		Frame.PLATE: _update_plate(cell, tile, delta)
		Frame.CRACKED: _update_cracked(cell, tile, delta)
		Frame.PASTE:
			if tile.phase == Phase.RESTING && tile.dissolve_at >= 0 && _time >= tile.dissolve_at:
				_set_phase(cell, Phase.BROKEN)
				Juice.burst(self, _centre(cell), PASTE_COLOR, 10, 30.0, Vector2.ZERO, 2.0, 0.5)

func _update_wires(cell: Vector2i, tile: Dictionary, delta: float) -> void:
	if tile.phase == Phase.BROKEN:
		return
	if tile.phase == Phase.WARNING && randf() < SPARK_CHANCE * delta:
		Juice.burst(self, _centre(cell), SPARK_COLOR, 3, 40.0, Vector2.ZERO, 1.0, 0.2)
	tile.left -= delta
	if tile.left > 0:
		return
	match tile.phase:
		Phase.RESTING: _set_phase(cell, Phase.WARNING, Tuning.wire_spark_time)
		Phase.WARNING: _go_live(cell)
		Phase.LIVE: _set_phase(cell, Phase.RESTING, Tuning.wire_idle_time)

func _update_plate(cell: Vector2i, tile: Dictionary, delta: float) -> void:
	if tile.phase == Phase.BROKEN:
		return
	if tile.phase == Phase.RESTING:
		# Waits to be stepped on (_affect); after going off it stays down until it re-arms.
		if tile.has("rearm_at") && _time >= tile.rearm_at:
			tile.erase("rearm_at")
			_show_frame(cell, Frame.PLATE)
		return
	tile.left -= delta
	if tile.left > 0:
		return
	match tile.phase:
		Phase.WARNING: _go_live(cell)
		Phase.LIVE:
			_set_phase(cell, Phase.RESTING)
			tile.rearm_at = _time + Tuning.plate_rearm_time
			_show_frame(cell, Frame.PLATE_DOWN)

func _update_cracked(cell: Vector2i, tile: Dictionary, delta: float) -> void:
	if tile.phase == Phase.RESTING:
		return
	tile.left -= delta
	if tile.left > 0:
		return
	if tile.phase == Phase.WARNING:
		_open_hole(cell)
	elif tile.phase == Phase.LIVE:
		_mend_hole(cell)

func _go_live(cell: Vector2i) -> void:
	var tile: Dictionary = _tiles[cell]
	tile.cycle += 1
	var live := Tuning.wire_live_time if tile.frame == Frame.WIRES else Tuning.plate_live_time
	_set_phase(cell, Phase.LIVE, live)
	# The clash window opens now, so it gets the twinkle an enemy shows as its parry window opens.
	Juice.twinkle(self, map_to_local(cell) + TWINKLE_OFFSET)
	Juice.burst(self, _centre(cell), SHOCK_COLOR, 8, 60.0, Vector2.ZERO, 1.5, 0.25)
	Juice.play(_sounds.shock, 0.08, SHOCK_PITCH)

func _open_hole(cell: Vector2i) -> void:
	_set_phase(cell, Phase.LIVE, Tuning.crack_respawn_time)
	_holes[cell].set_deferred("disabled", false)
	var nav := _room.nav_if_built()
	if nav != null:
		nav.set_blocked(cell, true)
	Juice.burst(self, _centre(cell), DUST, 14, 50.0, Vector2.ZERO, 2.0, 0.5)
	Juice.play(_sounds.crumble, 0.08)
	# Anything standing on it goes down. The player's FeetBox sees the new pit itself.
	for child in _room.get_children():
		var enemy := child as Enemy
		if _affects(enemy) && _cell_of(enemy.feet_position()) == cell:
			enemy.fall()

func _mend_hole(cell: Vector2i) -> void:
	_set_phase(cell, Phase.RESTING)
	_holes[cell].set_deferred("disabled", true)
	var nav := _room.nav_if_built()
	if nav != null:
		nav.set_blocked(cell, false)

# Moves `cell` to `phase` for `left` seconds and shows it.
func _set_phase(cell: Vector2i, phase: Phase, left := 0.0) -> void:
	var tile: Dictionary = _tiles[cell]
	tile.phase = phase
	tile.left = left
	_show_frame(cell, _frame_for(tile))
	if phase == Phase.BROKEN && tile.frame != Frame.CRACKED:
		var nav := _room.nav_if_built()
		if nav != null:
			nav.set_avoided(cell, false)

func _frame_for(tile: Dictionary) -> int:
	var phase: Phase = tile.phase
	match tile.frame:
		Frame.WIRES:
			return [Frame.WIRES, Frame.WIRES_SPARK, Frame.WIRES_LIVE, Frame.WIRES_BROKEN][phase]
		Frame.PLATE:
			return [Frame.PLATE, Frame.PLATE_DOWN, Frame.PLATE_LIVE, Frame.PLATE_BROKEN][phase]
		Frame.CRACKED:
			return [Frame.CRACKED, Frame.CRACKING, Frame.HOLE, Frame.CRACKED][phase]
		Frame.PASTE:
			return -1 if phase == Phase.BROKEN else Frame.PASTE
	return tile.frame

func _show_frame(cell: Vector2i, frame: int) -> void:
	if frame < 0:
		erase_cell(0, cell)
	else:
		set_cell(0, cell, 0, Vector2i(frame, 0))

# --- What happens to whoever stands on them ---

# A body's own state: the cell its feet were on, when its spikes next hurt, the wire or
# plate cycle that last shocked it, the paste holding it, and the teleporter it arrived on
# (it has to step off before that one works again).
func _record(body: Node2D) -> Dictionary:
	var id := body.get_instance_id()
	if !_bodies.has(id):
		_bodies[id] = {cell = Vector2i(-1, -1), spike_next = 0.0, shocked = {}, stuck = null,
			paste_free_until = 0.0, arrived = null, last_position = body.global_position,
			stretching = false, snapped = false}
	return _bodies[id]

# How much longer the paste holding `body` lasts, 1 just caught to 0 dissolved, or 0 if
# nothing holds it. Its status bar shows this (Player, Enemy).
func paste_left(body: Node) -> float:
	var record: Dictionary = _bodies.get(body.get_instance_id(), {})
	if record.get("stuck") == null || Tuning.paste_dissolve_time <= 0:
		return 0.0
	var tile: Dictionary = _tiles[record.stuck]
	if tile.phase == Phase.BROKEN:
		return 0.0
	return clampf((tile.dissolve_at - _time) / Tuning.paste_dissolve_time, 0.0, 1.0)

# The same for a body in `room`, which may have no special tiles.
static func paste_left_in(room: Node, body: Node) -> float:
	var layer := room.get_node_or_null(NODE_NAME) as SpecialTiles if room != null else null
	return layer.paste_left(body) if layer != null else 0.0

func _affect(body: CharacterBody2D, feet: Vector2, delta: float) -> void:
	var record := _record(body)
	var cell := _cell_of(feet)
	var entered: bool = cell != record.cell
	record.cell = cell
	var teleporter: Variant = teleporter_at(feet)
	if record.arrived != null && record.arrived != teleporter:
		record.arrived = null # Stepped off the square it arrived on
	if teleporter != null && record.arrived == null && _teleport(body, record, teleporter, feet):
		return
	var player := body as Player
	var rolling := player != null && player.rolling.time_left > 0
	var moved: float = (body.global_position - record.last_position).length() / maxf(delta, 0.0001)
	record.last_position = body.global_position
	if body is Enemy:
		(body as Enemy).animator.speed_scale = speed_factor(frame_at(_room, feet))
		_drift_on_ice(body as Enemy, feet, delta)

	if _tiles.has(cell):
		var tile: Dictionary = _tiles[cell]
		match tile.frame:
			Frame.SPIKES:
				if !rolling && (entered || _time >= record.spike_next):
					record.spike_next = _time + Tuning.spike_interval
					_hurt(body, Tuning.spike_damage)
			Frame.WIRES, Frame.PLATE:
				if tile.frame == Frame.PLATE && tile.phase == Phase.RESTING && !tile.has("rearm_at"):
					_set_phase(cell, Phase.WARNING, Tuning.plate_delay) # Click
					Juice.burst(self, _centre(cell), DUST, 4, 20.0, Vector2.ZERO, 1.0, 0.2)
				if tile.phase == Phase.LIVE && !rolling && record.shocked.get(cell, -1) != tile.cycle:
					record.shocked[cell] = tile.cycle
					_shock(body)
			Frame.CRACKED:
				if tile.phase == Phase.RESTING:
					_set_phase(cell, Phase.WARNING, Tuning.crack_time)
			Frame.PASTE:
				if tile.phase == Phase.RESTING && record.stuck == null && !rolling \
						&& _time >= record.paste_free_until:
					record.stuck = cell
					record.stretching = false
					if tile.dissolve_at < 0:
						tile.dissolve_at = _time + Tuning.paste_dissolve_time
					Juice.burst(self, feet, PASTE_COLOR, 6, 25.0, Vector2.ZERO, 1.5, 0.3)
					Juice.play(_sounds.stick, 0.08)
	_hold_in_paste(body, record, feet, moved, delta)

# A projectile over a teleporter goes through it like anything else, flying on the same way
# out of the far square. It flies at chest height, so it's drawn PROJECTILE_DROP above the
# floor it's over; it counts as over a teleporter if any of that span is, so a shot that
# looks like it crosses the square does.
func _carry_projectile(shot: Projectile) -> void:
	var record := _record(shot)
	var floor_point := shot.global_position + PROJECTILE_DROP
	var teleporter: Variant = null
	for step in PROJECTILE_SPAN_STEPS + 1:
		var point := shot.global_position + PROJECTILE_DROP * step / PROJECTILE_SPAN_STEPS
		teleporter = teleporter_at(point, PROJECTILE_GRACE)
		if teleporter != null:
			break
	if record.arrived != null && record.arrived != teleporter:
		record.arrived = null
	if teleporter != null && record.arrived == null:
		_teleport(shot, record, teleporter, floor_point)

func _hurt(body: Node2D, amount: float) -> void:
	if body is Player:
		(body as Player).take_damage(amount, "", false)
	elif body is Enemy:
		(body as Enemy).hurt_by_floor(amount)

func _shock(body: Node2D) -> void:
	Juice.burst(self, body.global_position, SHOCK_COLOR, 10, 70.0, Vector2.ZERO, 1.5, 0.3)
	_hurt(body, Tuning.shock_damage)
	var player := body as Player
	if player != null && Tuning.shock_daze > 0:
		player.daze(Tuning.shock_daze)

# Swinging into live wires or a live plate breaks it: a clank, sparks, and it's dead for good.
func _check_clash(player: Player) -> void:
	if !player.is_slashing() || player.swing_started_frame == _clashed_swing:
		return
	var feet := player.global_position + Player.FEET
	var ahead := Direction.to_vector(player.direction)
	for reach in SWORD_REACH:
		var cell := _cell_of(feet + ahead * reach)
		if !_tiles.has(cell):
			continue
		var tile: Dictionary = _tiles[cell]
		if tile.frame in [Frame.WIRES, Frame.PLATE] && tile.phase == Phase.LIVE:
			_clashed_swing = player.swing_started_frame
			_set_phase(cell, Phase.BROKEN)
			var at := _centre(cell)
			Juice.burst(self, at, Enemy.PARRY_SPARK, 14, 110.0, Vector2.ZERO, 2.0, 0.3)
			Juice.burst(self, at, SHOCK_COLOR, 10, 80.0, Vector2.ZERO, 1.5, 0.3)
			Juice.clank()
			Juice.hitstop(Enemy.PARRY_HITSTOP)
			Juice.shake(Juice.SHAKE_MEDIUM)
			return

# Moves `body` so that `feet` (the point of it that stands on tiles) lands in the middle of
# where `cell` sends things. False if `cell` has no partner, so nothing happened.
func _teleport(body: Node2D, record: Dictionary, cell: Vector2i, feet: Vector2) -> bool:
	var destination: Variant = teleport_destination(cell)
	if destination == null:
		return false
	var colour := _teleport_colour(painted(cell))
	Juice.burst(self, feet, colour, 12, 60.0, Vector2.ZERO, 1.5, 0.35)
	body.global_position += _centre(destination) - feet
	record.cell = destination
	record.arrived = destination
	record.stuck = null
	record.last_position = body.global_position
	var player := body as Player
	if player != null:
		player.knockback = Vector2.ZERO
	Juice.burst(self, _centre(destination), colour, 12, 60.0, Vector2.ZERO, 1.5, 0.35)
	Juice.play(_sounds.teleport, 0.08)
	return true

func _teleport_colour(frame: int) -> Color:
	var colours := [Color("e85050"), Color("4f8fff"), Color("4fd060"), Color("f0d040")]
	return colours[clampi(frame - Frame.TELEPORT_1, 0, TELEPORT_PAIRS - 1)]

# Caught in paste: kept within Tuning.paste_reach of the paste's edge, and pulled back to
# the middle whenever it stops moving. A roll (the player's) gets out, as does the paste
# dissolving.
func _hold_in_paste(body: CharacterBody2D, record: Dictionary, feet: Vector2, moved: float, delta: float) -> void:
	if record.stuck == null:
		return
	var cell: Vector2i = record.stuck
	var tile: Dictionary = _tiles[cell]
	var player := body as Player
	if tile.phase == Phase.BROKEN || (player != null && player.rolling.time_left > 0):
		record.stuck = null
		record.paste_free_until = _time + Tuning.roll_duration + 0.2 # Not caught again mid-roll
		return
	var centre := _centre(cell)
	var offset := feet - centre
	var half := Room.CELL_SIZE / 2.0 + Tuning.paste_reach
	var held := offset.clamp(-Vector2.ONE * half, Vector2.ONE * half)
	var walking := player.velocity.length() > MOVING_SPEED if player != null else moved > MOVING_SPEED
	# A creak the moment it pulls against the paste's limit, and a snap as the paste pulls
	# it back from out there.
	var at_limit := held != offset
	if at_limit && walking && !record.stretching:
		record.stretching = true
		Juice.play(_sounds.stretch, 0.08)
	if !walking:
		var pulled_back: bool = record.stretching || offset.length() >= PASTE_SNAP_DISTANCE
		if pulled_back && !record.snapped:
			Juice.play(_sounds.snap, 0.08)
			record.snapped = true # Once per pull back; walking again re-arms it
		record.stretching = false
		held = held.move_toward(Vector2.ZERO, Tuning.paste_pull * delta)
	else:
		record.snapped = false
	if held != offset:
		body.move_and_collide(held - offset)

# An enemy that didn't walk this frame keeps sliding on ice, slowing as it goes.
func _drift_on_ice(enemy: Enemy, feet: Vector2, delta: float) -> void:
	if !is_slick(frame_at(_room, feet)):
		enemy.slide = Vector2.ZERO
		return
	# A frozen enemy (Tuning.freeze_enemies) is out of the physics world and can't move.
	if enemy.walked_this_frame() || enemy.slide == Vector2.ZERO || !enemy.can_process():
		return
	enemy.slide = enemy.slide.move_toward(Vector2.ZERO, Tuning.enemy_slick_grip * delta)
	var collision := enemy.move_and_collide(enemy.slide * delta)
	if collision != null: # Slid into something: carry on along it, losing what went into it
		enemy.slide = enemy.slide.slide(collision.get_normal())
		enemy.move_and_collide(collision.get_remainder().slide(collision.get_normal()))

# Tiles work on every enemy but the boss (whose room has none anyway).
func _affects(node: Node) -> bool:
	var enemy := node as Enemy
	return enemy != null && enemy.scene_file_path != Room.BOSS_SCENE && !enemy.is_queued_for_deletion()

# --- Geometry ---

func _cell_of(global_point: Vector2) -> Vector2i:
	return local_to_map(to_local(global_point))

func _centre(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))
