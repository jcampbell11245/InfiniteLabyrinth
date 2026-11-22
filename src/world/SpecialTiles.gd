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
#             The sparking and live frames are animated (ANIMATIONS).
#   Plate     is stepped on, clicks down, then goes live like wires, then re-arms.
#             Swinging the sword into live wires or a live plate breaks it for good. Both
#             twinkle as they go live, as an enemy does when its parry window opens.
#   Spikes    lie flat until stepped on, then show their tips (the warning) for
#             Tuning.spike_warning_time and stab up. Up, they hurt whoever is on them, on
#             stepping on and again every Tuning.spike_interval, and stay up while anyone
#             is on them; Tuning.spike_up_time after the last one leaves, they go back down.
#   Cracked   cracks when stood on (two frames, deeper halfway), then opens into a pit,
#             then mends.
#   Paste     holds whoever steps in within Tuning.paste_reach of its edge, pulling them back
#             when they stop. It never wears off: the player breaks free with
#             Tuning.paste_rolls_to_escape rolls, counted down by a bar over their head
#             (paste_left), and enemies, which can't roll, stay held. It squelches on
#             catching, creaks when pulled against, and snaps as it pulls back.
#   Slick, Slow, Fast   change how things move while on them; the player and enemies ask
#             speed_factor() and is_slick() themselves.
#   Teleport  sends whoever steps on it, and any projectile flying over it, to the next
#             square of the same colour and symbol. It works from TELEPORT_GRACE pixels
#             outside its square, so feet brushing its edge still go through. The square
#             the player would be sent to glows while they're within
#             Tuning.teleport_glow_range of one. Going through squashes the square in
#             the way it was entered and stretches the far one out the same way.
#
# The player's roll keeps them from harm (the hurtbox is off while rolling, as for hits),
# and rolling is the way out of paste. Enemies are hurt and moved the same way, but walk
# round the dangerous tiles when they can (RoomNav reads avoided_cells()).

# Atlas columns of assets/sprites/tiles/special_tiles.png. A tile is painted with the first
# frame of its kind; frames after TELEPORT_4 are only ever shown by the rules, and go on the
# end so the columns rooms are painted with never move.
enum Frame {
	WIRES, WIRES_SPARK, WIRES_LIVE, WIRES_BROKEN,
	SPIKES,
	CRACKED, CRACKING, HOLE,
	SLICK,
	PLATE, PLATE_DOWN, PLATE_LIVE, PLATE_BROKEN,
	PASTE,
	SLOW, FAST,
	TELEPORT_1, TELEPORT_2, TELEPORT_3, TELEPORT_4,
	WIRES_SPARK_2, WIRES_SPARK_3, WIRES_SPARK_4, WIRES_SPARK_5, WIRES_SPARK_6,
	WIRES_LIVE_2, WIRES_LIVE_3,
	SPIKES_TIPS, SPIKES_STAB, SPIKES_UP,
	CRACKING_2,
}
# Frames that loop while shown, ANIMATION_FPS a second: the first frame -> the whole loop.
const ANIMATIONS := {
	Frame.WIRES_SPARK: [Frame.WIRES_SPARK, Frame.WIRES_SPARK_2, Frame.WIRES_SPARK_3,
		Frame.WIRES_SPARK_4, Frame.WIRES_SPARK_5, Frame.WIRES_SPARK_6],
	Frame.WIRES_LIVE: [Frame.WIRES_LIVE, Frame.WIRES_LIVE_2, Frame.WIRES_LIVE_3],
}
const ANIMATION_FPS := 10.0
const SPIKE_STAB_TIME := 0.1 # Seconds the spikes show their stab frame on coming up
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
const SFX_BUS := &"SFX"
const PASTE_STICK_SOUND := preload("res://assets/sfx/paste_stick.wav")
const PASTE_STRETCH_SOUND := preload("res://assets/sfx/paste_stretch.wav")
const PASTE_SNAP_SOUND := preload("res://assets/sfx/paste_snap.wav")
const PASTE_DB := -6.0
# Pulled back from at least this far past the paste's middle, the snap back is heard.
const PASTE_SNAP_DISTANCE := 10.0
const PASTE_REARM_DISTANCE := 3.0 # Back within this of the middle, the next pull back snaps again
const PASTE_EDGE_SLACK := 2.0 # Pixels short of the paste's limit that count as at it
const ENEMY_PASTE_IMMUNITY := 1.0 # Seconds after tearing free before paste can catch an enemy again
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
# Teleporter squish (_squish): the entered square's scale along and across the way it was
# entered, and how far it's pushed; the same for the square stretched out of; and how long
# they take to spring back.
const SQUISH_ALONG := 0.55
const SQUISH_ACROSS := 1.3
const SQUISH_SHIFT := 3.0
const STRETCH_ALONG := 1.35
const STRETCH_ACROSS := 0.75
const STRETCH_SHIFT := 2.0
const SQUISH_IN_TIME := 0.06
const SQUISH_HOLD := 0.05
const SQUISH_TIME := 0.5

var _room: Room
# Cell -> {frame: Frame it was painted with, phase: Phase, left: seconds in the phase,
# cycle: times it has gone live (wires, plates)}.
var _tiles := {}
var _holes := {} # Cell -> StaticBody2D on the pitfall layer, its shape on while the hole is open
var _bodies := {} # Instance id -> per-body record (see _record)
var _time := 0.0
var _clashed_swing := -1 # Player.swing_started_frame of the swing that last broke a tile
var _sounds := {}
var _glow: Sprite2D # Brightens the teleporter the player would be sent to
var _occupied := {} # Cells someone's feet are on this frame
var _held := {} # Paste cells holding someone this frame
var _squishes := {} # Teleporter cell -> the Sprite2D springing back on it (_squish)
var _fx: SpecialTilesFx # Draws the tiles' little animations over them

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
	var layer := _layer_in(room)
	return layer.frame_under(global_point) if layer != null else -1

# The frame painted under `global_point` on this layer, or -1.
func frame_under(global_point: Vector2) -> int:
	return painted(local_to_map(to_local(global_point)))

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

# A picture of `frame`, for the room creator's tool buttons.
static func icon(frame: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = TEXTURE
	# Flat spikes would read as a grate, so their button shows them up.
	var shown := Frame.SPIKES_UP if frame == Frame.SPIKES else frame
	texture.region = Rect2(shown * Room.CELL_SIZE, 0, Room.CELL_SIZE, Room.CELL_SIZE)
	return texture

# The room's layer, made (empty) if it has none yet.
static func of(room: Node) -> SpecialTiles:
	var layer := room.get_node_or_null(NODE_NAME) as SpecialTiles
	if layer == null:
		layer = (load(SCENE) as PackedScene).instantiate()
		layer.name = NODE_NAME
		room.add_child(layer)
	return layer

# Every painted cell. In a room that's what was painted when it loaded, so a tile that's
# briefly not drawn (a teleporter mid-squish, _squish) still counts.
func painted_cells() -> Array[Vector2i]:
	if !_tiles.is_empty():
		var cells: Array[Vector2i] = []
		cells.assign(_tiles.keys())
		return cells
	return get_used_cells(0)

# --- Read by SpecialTilesFx ---

# The running state of the tile on `cell` (frame, phase, seconds left in it), or an empty
# dictionary outside a room. For reading only.
func tile_state(cell: Vector2i) -> Dictionary:
	return _tiles.get(cell, {})

# True if the paste on `cell` is holding someone this frame.
func is_holding_at(cell: Vector2i) -> bool:
	return _held.has(cell)

# Seconds the rules have run for, which the animations are timed by.
func clock() -> float:
	return _time

# Cells enemies should keep off when they can: anything that hurts or holds them.
func avoided_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in painted_cells():
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
	for other: Vector2i in painted_cells():
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
	for cell: Vector2i in painted_cells():
		if !is_teleport(painted(cell)) || teleport_destination(cell) == null:
			continue
		# Measured to the square's edge, so the range is the same from every side.
		var rect := _cell_rect(cell)
		var distance := (local.clamp(rect.position, rect.end) - local).length()
		if distance <= reach && distance < best_distance:
			best = cell
			best_distance = distance
	return best

# The teleporter the destination glow is on, or null if it's off. Only the tests use it.
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
		var tile := {frame = frame, phase = Phase.RESTING, left = 0.0, cycle = 0}
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
	_fx = SpecialTilesFx.new()
	_fx.layer = self
	add_child(_fx)

func _add_sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.volume_db = volume_db
	# Sound effects go on the SFX bus, which the SFX volume slider controls, once the
	# project has one; until then they stay on Master.
	if AudioServer.get_bus_index(SFX_BUS) != -1:
		sound.bus = SFX_BUS
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
	_occupied.clear()
	_held.clear()
	if player.visible:
		_affect(player, player.global_position + Player.FEET, delta)
		seen[player.get_instance_id()] = true
	for child in _room.get_children():
		var enemy := child as Enemy
		if _affects(enemy):
			_affect(enemy, enemy.feet_position(), delta)
			seen[enemy.get_instance_id()] = true
	_show_plates()
	_fx.step(delta)
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
	_glow.scale = Vector2.ONE
	if _squishes.has(destination): # Glows squished along with it
		var squish: Sprite2D = _squishes[destination]
		_glow.position = squish.position
		_glow.scale = squish.scale
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
		Frame.SPIKES: _update_spikes(cell, tile, delta)
	if tile.frame in [Frame.WIRES, Frame.CRACKED, Frame.SPIKES]: # Their frames change with time
		var frame := _frame_for(tile)
		if get_cell_atlas_coords(0, cell).x != frame:
			_show_frame(cell, frame)


# A plate is drawn raised whenever nobody's standing on it (even while it re-arms), and
# pressed while somebody is; live, it shows its sparks either way.
func _show_plates() -> void:
	for cell: Vector2i in _tiles:
		var tile: Dictionary = _tiles[cell]
		if tile.frame != Frame.PLATE || tile.phase in [Phase.LIVE, Phase.BROKEN]:
			continue
		_show_frame(cell, Frame.PLATE_DOWN if _occupied.has(cell) else Frame.PLATE)

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
		return
	tile.left -= delta
	if tile.left > 0:
		return
	match tile.phase:
		Phase.WARNING: _go_live(cell)
		Phase.LIVE:
			_set_phase(cell, Phase.RESTING)
			tile.rearm_at = _time + Tuning.plate_rearm_time

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

# Up while anyone's on them (_occupied is still last frame's here), then down a while after.
func _update_spikes(cell: Vector2i, tile: Dictionary, delta: float) -> void:
	if tile.phase == Phase.RESTING:
		return # Waits to be stepped on (_step_on)
	if tile.phase == Phase.LIVE && _occupied.has(cell):
		tile.left = Tuning.spike_up_time
		return
	tile.left -= delta
	if tile.left > 0:
		return
	if tile.phase == Phase.WARNING:
		tile.cycle += 1
		tile.live_at = _time
		_set_phase(cell, Phase.LIVE, Tuning.spike_up_time)
	else:
		_set_phase(cell, Phase.RESTING)

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

# The frame `tile` shows now: by its phase, then by how far into the phase it is.
func _frame_for(tile: Dictionary) -> int:
	var phase: Phase = tile.phase
	var frame: int = tile.frame
	match tile.frame:
		Frame.WIRES:
			frame = [Frame.WIRES, Frame.WIRES_SPARK, Frame.WIRES_LIVE, Frame.WIRES_BROKEN][phase]
		Frame.PLATE:
			frame = [Frame.PLATE, Frame.PLATE_DOWN, Frame.PLATE_LIVE, Frame.PLATE_BROKEN][phase]
		Frame.CRACKED:
			frame = [Frame.CRACKED, Frame.CRACKING, Frame.HOLE, Frame.CRACKED][phase]
			if phase == Phase.WARNING && tile.left < Tuning.crack_time / 2.0:
				frame = Frame.CRACKING_2
		Frame.SPIKES:
			frame = [Frame.SPIKES, Frame.SPIKES_TIPS, Frame.SPIKES_UP, Frame.SPIKES][phase]
			if phase == Phase.LIVE && _time - float(tile.get("live_at", 0.0)) < SPIKE_STAB_TIME:
				frame = Frame.SPIKES_STAB
	if ANIMATIONS.has(frame):
		var loop: Array = ANIMATIONS[frame]
		frame = loop[floori(_time * ANIMATION_FPS) % loop.size()]
	return frame

func _show_frame(cell: Vector2i, frame: int) -> void:
	if frame < 0:
		erase_cell(0, cell)
	else:
		set_cell(0, cell, 0, Vector2i(frame, 0))

# --- What happens to whoever stands on them ---

# A body's own state: the cell its feet were on, when its spikes next hurt, the spikes
# cycle (cell -> times they've come up) that last hurt it, the wire or
# plate cycle that last shocked it, the paste holding it, and the teleporter it arrived on
# (it has to step off before that one works again).
func _record(body: Node2D) -> Dictionary:
	var id := body.get_instance_id()
	if !_bodies.has(id):
		_bodies[id] = {cell = Vector2i(-1, -1), spike_next = 0.0, spiked = {}, shocked = {}, stuck = null,
			paste_free_until = 0.0, arrived = null,
			stretching = false, snapped = false, snaps = 0, rolls = 0, was_rolling = false,
			strain = 0.0, hauling = false, edges = 0}
	return _bodies[id]

# --- Paste, asked about from outside (Player, Enemy and tests) ---
# Each instance method answers for this layer; the static *_in versions take the room a body
# is in, which may have no layer. Neither shows other scripts the per-body records.

# Where the feet of `body` may go while paste holds it (global pixels: the paste's square
# grown by Tuning.paste_reach), or null if nothing holds it. Enemies stop walking at its
# edge (Enemy.ground_motion).
func paste_bounds(body: Node) -> Variant:
	var stuck: Variant = _bodies.get(body.get_instance_id(), {}).get("stuck")
	if stuck == null:
		return null
	var square := Rect2(to_global(Vector2(stuck as Vector2i) * Room.CELL_SIZE), Vector2.ONE * Room.CELL_SIZE)
	return square.grow(Tuning.paste_reach)

# True while paste hauls `body` (an enemy) back to its middle, after it strained at the edge
# for Tuning.paste_enemy_strain_time. It can't walk meanwhile (Enemy.ground_motion).
func is_hauling(body: Node) -> bool:
	return _bodies.get(body.get_instance_id(), {}).get("hauling", false)

# How much the paste holding `body` still holds it: the share of the rolls (player) or trips
# to the edge (enemy) it needs to escape that it has yet to make, 1 just caught down towards
# 0, or 0 if nothing holds it. Its status bar shows this (Player, Enemy).
func paste_left(body: Node) -> float:
	var record: Dictionary = _bodies.get(body.get_instance_id(), {})
	if record.get("stuck") == null:
		return 0.0
	# The player escapes by rolling, an enemy by reaching the edge often enough.
	var needed := maxi(Tuning.paste_rolls_to_escape if body is Player else Tuning.paste_enemy_escape_edges, 1)
	var done: int = record.rolls if body is Player else record.edges
	return clampf(float(needed - done) / needed, 0.0, 1.0)

static func paste_bounds_in(room: Node, body: Node) -> Variant:
	var layer := _layer_in(room)
	return layer.paste_bounds(body) if layer != null else null

static func is_hauled_in(room: Node, body: Node) -> bool:
	var layer := _layer_in(room)
	return layer != null && layer.is_hauling(body)

static func paste_left_in(room: Node, body: Node) -> float:
	var layer := _layer_in(room)
	return layer.paste_left(body) if layer != null else 0.0

# True while paste holds `body` in `room`. Only the tests use it; game code asks
# paste_bounds_in, which says where the body may go as well.
static func is_stuck_in(room: Node, body: Node) -> bool:
	return paste_bounds_in(room, body) != null

# The room's SpecialTiles layer, or null if it has none (or there's no room).
static func _layer_in(room: Node) -> SpecialTiles:
	return room.get_node_or_null(NODE_NAME) as SpecialTiles if room != null else null

func _affect(body: CharacterBody2D, feet: Vector2, delta: float) -> void:
	var record := _record(body)
	var cell := _cell_of(feet)
	var entered: bool = cell != record.cell
	record.cell = cell
	_occupied[cell] = true
	var teleporter: Variant = teleporter_at(feet)
	if record.arrived != null && record.arrived != teleporter:
		record.arrived = null # Stepped off the square it arrived on
	if teleporter != null && record.arrived == null && _teleport(body, record, teleporter, feet):
		return
	var player := body as Player
	var rolling := player != null && player.rolling.time_left > 0
	if body is Enemy:
		(body as Enemy).animator.speed_scale = (body as Enemy).ground_factor() # With any server speed boost
		_drift_on_ice(body as Enemy, feet, delta)

	if _tiles.has(cell):
		_step_on(body, record, cell, feet, entered, rolling)
	_hold_in_paste(body, record, feet, delta)

# What the tile on `cell` does to `body`, whose feet are on it (just `entered`, or still).
# A roll keeps the player from spikes, shocks and paste.
func _step_on(body: CharacterBody2D, record: Dictionary, cell: Vector2i, feet: Vector2,
		entered: bool, rolling: bool) -> void:
	var tile: Dictionary = _tiles[cell]
	match tile.frame:
		Frame.SPIKES:
			# A roll passes over flat spikes without setting them off.
			if tile.phase == Phase.RESTING && !rolling:
				_set_phase(cell, Phase.WARNING, Tuning.spike_warning_time)
			elif tile.phase == Phase.LIVE && !rolling && (entered || _time >= record.spike_next \
					|| record.spiked.get(cell, -1) != tile.cycle):
				record.spiked[cell] = tile.cycle
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
			if record.stuck == null && !rolling && _time >= record.paste_free_until:
				_catch_in_paste(record, cell, feet)

# The paste on `cell` catches whoever `record` is for, starting their escape afresh.
func _catch_in_paste(record: Dictionary, cell: Vector2i, feet: Vector2) -> void:
	record.stuck = cell
	record.stretching = false
	record.snapped = false
	record.strain = 0.0
	record.hauling = false
	record.edges = 0
	record.rolls = 0
	record.was_rolling = false
	Juice.burst(self, feet, PASTE_COLOR, 6, 25.0, Vector2.ZERO, 1.5, 0.3)
	Juice.play(_sounds.stick, 0.08)

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
	var colour := teleport_colour(painted(cell))
	Juice.burst(self, feet, colour, 12, 60.0, Vector2.ZERO, 1.5, 0.35)
	var travel := _travel_direction(body, cell, feet)
	_squish(cell, travel, true)
	_squish(destination, travel, false)
	body.global_position += _centre(destination) - feet
	record.cell = destination
	record.arrived = destination
	record.stuck = null
	var player := body as Player
	if player != null:
		player.knockback = Vector2.ZERO
	Juice.burst(self, _centre(destination), colour, 12, 60.0, Vector2.ZERO, 1.5, 0.35)
	Juice.play(_sounds.teleport, 0.08)
	return true

# Which way something was going as it went into a teleporter: a projectile the way it
# flies, a body from where its feet came onto the square towards the middle (or the way it
# was moving, if it's dead centre).
func _travel_direction(body: Node2D, cell: Vector2i, feet: Vector2) -> Vector2:
	var shot := body as Projectile
	if shot != null:
		return Direction.to_vector(shot.direction)
	var inward := _centre(cell) - feet
	if inward.length() >= 1.0:
		return inward.normalized()
	var mover := body as CharacterBody2D
	return mover.velocity.normalized() if mover != null else Vector2.ZERO

# The teleporter on `cell` squashes along `travel`, pushed the way it was entered, and
# springs back; the square it sends to (`entered` false) stretches out the same way, as
# if pushed out of. Shown on a sprite over the cell, which isn't drawn meanwhile.
func _squish(cell: Vector2i, travel: Vector2, entered: bool) -> void:
	if _squishes.has(cell): # Still springing back from the last one
		var old: Sprite2D = _squishes[cell]
		old.queue_free()
	var frame := painted(cell)
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame * Room.CELL_SIZE, 0, Room.CELL_SIZE, Room.CELL_SIZE)
	var home := map_to_local(cell)
	sprite.position = home
	add_child(sprite)
	_squishes[cell] = sprite
	erase_cell(0, cell)
	var horizontal := absf(travel.x) >= absf(travel.y)
	var along := SQUISH_ALONG if entered else STRETCH_ALONG
	var across := SQUISH_ACROSS if entered else STRETCH_ACROSS
	var squashed := Vector2(along, across) if horizontal else Vector2(across, along)
	if travel == Vector2.ZERO:
		squashed = Vector2.ONE * SQUISH_ALONG # Straight down onto it: squashed all round
	var pushed := home + travel * (SQUISH_SHIFT if entered else STRETCH_SHIFT)
	# Into the squash quickly, a moment held there, then a wobbly spring back.
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", squashed, SQUISH_IN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position", pushed, SQUISH_IN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SQUISH_HOLD)
	tween.tween_property(sprite, "scale", Vector2.ONE, SQUISH_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "position", home, SQUISH_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_end_squish.bind(cell, sprite))

func _end_squish(cell: Vector2i, sprite: Sprite2D) -> void:
	if _squishes.get(cell) == sprite:
		_squishes.erase(cell)
		_show_frame(cell, painted(cell))
	sprite.queue_free()

static func teleport_colour(frame: int) -> Color:
	var colours := [Color("e85050"), Color("4f8fff"), Color("4fd060"), Color("f0d040")]
	return colours[clampi(frame - Frame.TELEPORT_1, 0, TELEPORT_PAIRS - 1)]

# Caught in paste: kept within Tuning.paste_reach of the paste's edge, and pulled back to
# the middle whenever it stops moving. The player gets out with Tuning.paste_rolls_to_escape
# rolls (the ones before only strain against it); otherwise it holds for good.
# Enemies walk as usual inside it, run on the spot at its edge (Enemy.ground_motion), and
# are hauled back to the middle after Tuning.paste_enemy_strain_time there.
func _hold_in_paste(body: CharacterBody2D, record: Dictionary, feet: Vector2, delta: float) -> void:
	if record.stuck == null:
		return
	var cell: Vector2i = record.stuck
	var player := body as Player
	_held[cell] = true
	if player != null && _rolled_free(player, record, feet):
		return
	var offset := feet - _centre(cell)
	var half := Room.CELL_SIZE / 2.0 + Tuning.paste_reach
	var held := offset.clamp(-Vector2.ONE * half, Vector2.ONE * half)
	# Enemies stop just short of the edge (their next step would cross it), hence the slack.
	var at_limit := held != offset || maxf(absf(offset.x), absf(offset.y)) >= half - PASTE_EDGE_SLACK
	var pull := _player_pulled(player, record, at_limit) if player != null \
		else _enemy_pulled(record, at_limit, offset, feet, delta)
	if record.stuck == null: # The enemy tore free
		return
	if pull:
		var speed := Tuning.paste_pull if player != null else Tuning.paste_enemy_pull
		held = _pull_back(record, held, offset, speed * delta)
	if offset.length() <= PASTE_REARM_DISTANCE:
		_back_in_the_middle(record)
	if held != offset:
		body.move_and_collide(held - offset)

# Counts the player's rolls against the paste: the ones before the last strain against it
# (a creak, higher each time); the last tears them free. True if they're free.
func _rolled_free(player: Player, record: Dictionary, feet: Vector2) -> bool:
	var rolling := player.rolling.time_left > 0
	var new_roll: bool = rolling && !record.was_rolling
	record.was_rolling = rolling
	if !new_roll:
		return false
	record.rolls += 1
	var heading := Direction.to_vector(player.direction)
	if record.rolls >= Tuning.paste_rolls_to_escape:
		_free_from_paste(record, feet, heading, Tuning.roll_duration + 0.2) # Not caught again mid-roll
		return true
	Juice.burst(self, feet, PASTE_COLOR, 6, 40.0, heading, 1.5, 0.3)
	Juice.play(_sounds.stretch, 0.08, 1.0 + 0.15 * record.rolls) # Higher as it gives
	return false

# The player creaks at the paste's limit and is pulled back whenever they stop walking.
# True if the paste pulls them this frame.
func _player_pulled(player: Player, record: Dictionary, at_limit: bool) -> bool:
	var walking := player.velocity.length() > MOVING_SPEED
	if at_limit && walking && !record.stretching:
		record.stretching = true
		Juice.play(_sounds.stretch, 0.08)
	if walking:
		return false
	record.stretching = false
	return true

# An enemy runs on the spot at the edge (Enemy.ground_motion) for
# Tuning.paste_enemy_strain_time, then is slowly hauled back to the middle
# (Tuning.paste_enemy_pull), where it can set off again; it can't walk while hauled
# (is_hauling). The Tuning.paste_enemy_escape_edges-th time it reaches the edge, it tears
# free. True if the paste pulls it this frame.
func _enemy_pulled(record: Dictionary, at_limit: bool, offset: Vector2, feet: Vector2, delta: float) -> bool:
	if record.hauling:
		return true
	if !at_limit:
		record.stretching = false
		record.strain = 0.0
		return false
	if !record.stretching: # Just reached the edge
		record.stretching = true
		record.edges += 1
		if record.edges >= Tuning.paste_enemy_escape_edges:
			_free_from_paste(record, feet, offset.normalized())
			return false
		Juice.play(_sounds.stretch, 0.08)
	record.strain += delta
	if record.strain < Tuning.paste_enemy_strain_time:
		return false
	record.hauling = true
	return true

# Moves the held offset `step` pixels back towards the paste's middle. One snap as the pull
# back starts; it's heard again only once they've been back in the middle, so a pull back
# that stops and starts makes just the one.
func _pull_back(record: Dictionary, held: Vector2, offset: Vector2, step: float) -> Vector2:
	if !record.snapped && offset.length() >= PASTE_SNAP_DISTANCE:
		Juice.play(_sounds.snap, 0.08)
		record.snapped = true
		record.snaps += 1
	return held.move_toward(Vector2.ZERO, step)

# Back in the paste's middle: the next pull back may snap, and a hauled enemy may set off again.
func _back_in_the_middle(record: Dictionary) -> void:
	record.snapped = false
	if record.hauling:
		record.hauling = false
		record.stretching = false
		record.strain = 0.0

# Lets go of whoever `record` is for, tearing free towards `direction`; the same paste can't
# catch them again for `immune_for` seconds, so they get clear of it.
func _free_from_paste(record: Dictionary, feet: Vector2, direction: Vector2,
		immune_for := ENEMY_PASTE_IMMUNITY) -> void:
	record.stuck = null
	record.hauling = false
	record.stretching = false
	record.paste_free_until = _time + immune_for
	Juice.burst(self, feet, PASTE_COLOR, 14, 70.0, direction, 2.0, 0.4)
	Juice.play(_sounds.snap, 0.08, 1.3)

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

# Tiles work on every enemy but the boss (whose room has none anyway) and those that fly
# over them (Enemy.flies).
func _affects(node: Node) -> bool:
	var enemy := node as Enemy
	return enemy != null && enemy.scene_file_path != Room.BOSS_SCENE && !enemy.flies() \
		&& !enemy.is_queued_for_deletion()

# --- Geometry ---

func _cell_of(global_point: Vector2) -> Vector2i:
	return local_to_map(to_local(global_point))

func _centre(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))
