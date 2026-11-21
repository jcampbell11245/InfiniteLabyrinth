class_name CaveLighting
extends Node

# Darkens the cave and lights it with a few soft 2D lights. Overworld adds one to every
# floor.
#
# The light is worked out at the game's pixel size, so its edges step in whole pixels like
# the art instead of being smooth at screen resolution. A small SubViewport shares the
# world, one texel per world pixel, and draws only a plain "receiver" rectangle in the
# cave's ambient colour, which the lights brighten and the walls shadow: that is the light
# map. A sprite drawn over the whole world multiplies the screen by it (light_map.gdshader),
# sampled nearest. It sits in the world canvas, so the HUD's CanvasLayers stay unlit.
#
# PointLight2Ds add light: a warm one carried by the player, and small coloured ones on
# fireballs and lasers so they stand out in the dark, and a blue one on knights, whose
# visor and sword also glow (GlowMask). Dropped loot doesn't glow. Inner walls block the light: each room gets light
# occluders over its wall cells, so they cast shadows. Lights and occluders are attached as
# nodes spawn, so nothing else needs to know about lighting. Every number is in Tuning (the
# F2 menu's Lighting tab) and applies live.
#
# The start and end rooms stay fully lit: walking into one fades the darkness (and the
# lights, which would only wash it out) away, and walking out brings them back.

const LIGHT_NAME := &"CaveLight"
const OCCLUDER_NAME := &"WallShadow"
const WALL_INSET := 6.0 # Pixels a wall's shadow starts inside its open edges
# Projectile scenes that glow; arrows don't.
const GLOWING_PROJECTILES := ["Fireball", "Laser"]
const KNIGHT_SCENES := ["Knight", "DualKnight"] # Their visors and swords glow blue
# Pixels across the generated light texture. Big, because the player's light stretches it
# over most of a room and coarse texels show up as rings.
const TEXTURE_SIZE := 512
const FALLOFF_STOPS := 32 # Gradient points along the falloff curve; few points show as bands

const PLAYER_COLOR := Color(1.0, 0.86, 0.62) # Torch-warm
const FIREBALL_COLOR := Color(1.0, 0.55, 0.2)
const LASER_COLOR := Color(1.0, 0.3, 0.3)
const KNIGHT_COLOR := Color(0.3, 0.8, 1.0) # The cyan of their visors

enum Kind { PLAYER, PROJECTILE, KNIGHT }

# A visibility and light layer of its own for the receiver: only the light map's viewport
# draws it, and the lights only light it, never the sprites themselves.
const RECEIVER_LAYER := 1 << 19
const LIGHT_MAP_SHADER := preload("res://src/world/light_map.gdshader")
const RECEIVER_SHADER := preload("res://src/world/light_receiver.gdshader")
const LIGHT_MAP_MARGIN := 4 # World pixels drawn past each screen edge, so shake doesn't show the border
# The map holds light at half strength, so a light can brighten a pixel past its art
# (the shader doubles it back); 1 here is "as drawn".
const LIGHT_MAP_SCALE := 0.5

# How fast each channel darkens, against 1 for grey: blue holds on longest.
const SHADOW_TINT := Color(1.15, 1.1, 0.8)

const BRIGHT_ROOMS := [Constants.START_ROOM, Constants.END_ROOM]
const BRIGHT_FADE_TIME := 0.5 # Real seconds the darkness takes to lift or fall on changing rooms

var _light_map: SubViewport
var _map_camera: Camera2D
var _receiver: ColorRect # What the lights fall on, in the light map only
var _overlay: Sprite2D # Multiplies the world by the light map
var _texture: GradientTexture2D
var _brightness_lift := 0.0 # 0 in the dark cave, 1 in a room kept fully lit
var _room_brightness := 1.0 # The current room's Room.brightness, faded between rooms
var _lift_tween: Tween
var _seen_room := false # The first room is set at once, not faded to

func _ready() -> void:
	_build_light_map()
	get_tree().node_added.connect(_on_node_added)
	Tuning.changed.connect(_on_tuning_changed)
	Game.room_entered.connect(_on_room_entered)
	# Light what already exists on the floor (the player is in it before this runs).
	for node in get_parent().find_children("*", "", true, false):
		_on_node_added(node)
	_apply_all()

func _exit_tree() -> void:
	get_viewport().canvas_cull_mask |= RECEIVER_LAYER

func _build_light_map() -> void:
	# The game's own view must never draw the receiver.
	get_viewport().canvas_cull_mask &= ~RECEIVER_LAYER
	_light_map = SubViewport.new()
	_light_map.name = "LightMap"
	_light_map.world_2d = get_viewport().world_2d
	_light_map.canvas_cull_mask = RECEIVER_LAYER
	_light_map.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_light_map)
	_map_camera = Camera2D.new()
	_light_map.add_child(_map_camera)
	_map_camera.make_current()
	_receiver = ColorRect.new()
	_receiver.name = "Receiver"
	_receiver.visibility_layer = RECEIVER_LAYER
	_receiver.light_mask = RECEIVER_LAYER
	_receiver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var receiver_material := ShaderMaterial.new()
	receiver_material.shader = RECEIVER_SHADER
	_receiver.material = receiver_material
	_light_map.add_child(_receiver)
	_overlay = Sprite2D.new()
	_overlay.name = "LightOverlay"
	_overlay.texture = _light_map.get_texture()
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.light_mask = 0
	_overlay.z_as_relative = false
	_overlay.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	var material := ShaderMaterial.new()
	material.shader = LIGHT_MAP_SHADER
	_overlay.material = material
	# A Node2D parent is needed for it to draw in the world; this Node isn't one.
	var holder := Node2D.new()
	holder.name = "LightOverlayHolder"
	add_child(holder)
	holder.add_child(_overlay)

# Keeps the light map over what the game camera sees, snapped to whole world pixels so a
# texel always covers one game pixel.
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport().get_visible_rect().size / camera.zoom
	var size := Vector2i(ceili(view.x / 2.0) * 2, ceili(view.y / 2.0) * 2) + Vector2i.ONE * LIGHT_MAP_MARGIN * 2
	if _light_map.size != size:
		_light_map.size = size
	var centre := camera.get_screen_center_position().round()
	_map_camera.position = centre
	_receiver.position = centre - Vector2(size) / 2.0
	_receiver.size = Vector2(size)
	_overlay.position = centre

# The soft round falloff every light uses: bright in the middle, fading to nothing at the
# edge along a smootherstep curve, which has no corners for the eye to pick out as rings.
# Made once per floor in code and shared by its lights (not static, so it is freed with
# the floor instead of outliving the game at exit).
func light_texture() -> GradientTexture2D:
	if _texture == null:
		var offsets := PackedFloat32Array()
		var colors := PackedColorArray()
		for i in FALLOFF_STOPS + 1:
			var t := float(i) / FALLOFF_STOPS
			var fade := 1.0 - t
			offsets.append(t)
			colors.append(Color(1, 1, 1, fade * fade * fade * (fade * (fade * 6.0 - 15.0) + 10.0)))
		var gradient := Gradient.new()
		gradient.offsets = offsets
		gradient.colors = colors
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture

# The colour the unlit cave is multiplied by: Tuning.cave_brightness times the room's own
# brightness, with the darkness leaning blue (red and green fall off faster) so shadows read
# as cold stone rather than grey. The tint goes with the darkness, so a fully lit room is
# white. Blended to white as a bright room's lift comes in.
func ambient_color() -> Color:
	if !Tuning.lighting_enabled:
		return Color.WHITE
	var dark := 1.0 - clampf(Tuning.cave_brightness * _room_brightness, 0.0, 1.0)
	var shade := Color(1.0 - dark * SHADOW_TINT.r, 1.0 - dark * SHADOW_TINT.g, 1.0 - dark * SHADOW_TINT.b)
	return shade.clamp().lerp(Color.WHITE, _brightness_lift)

# Fades to the new room's light: fully lit in a bright room, otherwise the room's own
# brightness.
func _on_room_entered(room_id: int) -> void:
	var room := Game.room_by_id(room_id)
	var lift := 1.0 if room_id in BRIGHT_ROOMS else 0.0
	var level := room.brightness if room != null else 1.0
	if _lift_tween != null:
		_lift_tween.kill()
	if !_seen_room:
		_seen_room = true
		_set_room_light(lift, level)
		return
	var from_lift := _brightness_lift
	var from_level := _room_brightness
	_lift_tween = create_tween().set_ignore_time_scale()
	_lift_tween.tween_method(func(t: float) -> void:
		_set_room_light(lerpf(from_lift, lift, t), lerpf(from_level, level, t)),
		0.0, 1.0, BRIGHT_FADE_TIME)

func _set_room_light(lift: float, level: float) -> void:
	_brightness_lift = lift
	_room_brightness = level
	_apply_all()

func _on_node_added(node: Node) -> void:
	if node.has_node(NodePath(LIGHT_NAME)):
		return
	if node is Player:
		_put_at_feet(_add_light(node, Kind.PLAYER, PLAYER_COLOR), node)
	elif node is MeleeEnemy && node.scene_file_path.get_file().get_basename() in KNIGHT_SCENES:
		_put_at_feet(_add_light(node, Kind.KNIGHT, KNIGHT_COLOR), node)
		var sprite := node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null && !sprite.has_node("GlowMask"):
			GlowMask.attach.call_deferred(sprite)
	elif node is Projectile:
		var scene := node.scene_file_path.get_file().get_basename()
		if scene in GLOWING_PROJECTILES:
			_add_light(node, Kind.PROJECTILE, LASER_COLOR if scene == "Laser" else FIREBALL_COLOR)
	elif node is Room:
		# Deferred so the room's children (its wall map among them) are all in place.
		_add_wall_occluders.call_deferred(node)

# Covers a room's inner walls with light occluders, so the walls cast shadows. Each is
# inset by WALL_INSET from edges that face open floor, so the side of a wall facing a light
# is lit and only the far side falls into shadow; edges against another wall stay flush so
# no light leaks between them. Cells in a row with the same walls above and below share
# one occluder, so a floor has far fewer for the lights to test.
func _add_wall_occluders(room: Room) -> void:
	var walls := room.get_node_or_null("InnerWalls") as TileMap
	if walls == null || room.has_node(NodePath(OCCLUDER_NAME)):
		return
	# The occluders can't be children of the wall map: the light map's viewport skips
	# whatever isn't on its visibility layer, children included. They hang off a node that
	# draws nothing, placed where the wall map is.
	var holder := Node2D.new()
	holder.name = OCCLUDER_NAME
	holder.transform = walls.transform
	holder.visibility_layer |= RECEIVER_LAYER
	room.add_child(holder)
	var cell_size := Vector2(walls.tile_set.tile_size)
	var is_wall := {}
	for cell in walls.get_used_cells(0):
		is_wall[cell] = true
	var same_row := func(a: Vector2i, b: Vector2i) -> bool:
		return is_wall.has(b) && is_wall.has(a + Vector2i.UP) == is_wall.has(b + Vector2i.UP) 				&& is_wall.has(a + Vector2i.DOWN) == is_wall.has(b + Vector2i.DOWN)
	for cell: Vector2i in is_wall:
		if same_row.call(cell, cell + Vector2i.LEFT):
			continue # Not the start of a run
		var last := cell
		while same_row.call(cell, last + Vector2i.RIGHT):
			last += Vector2i.RIGHT
		var top_left := walls.map_to_local(cell) - cell_size / 2.0
		var bottom_right := walls.map_to_local(last) + cell_size / 2.0
		top_left += Vector2(
			0.0 if is_wall.has(cell + Vector2i.LEFT) else WALL_INSET,
			0.0 if is_wall.has(cell + Vector2i.UP) else WALL_INSET)
		bottom_right -= Vector2(
			0.0 if is_wall.has(last + Vector2i.RIGHT) else WALL_INSET,
			0.0 if is_wall.has(cell + Vector2i.DOWN) else WALL_INSET)
		var shape := OccluderPolygon2D.new()
		shape.polygon = PackedVector2Array([top_left, Vector2(bottom_right.x, top_left.y),
				bottom_right, Vector2(top_left.x, bottom_right.y)])
		var occluder := LightOccluder2D.new()
		occluder.occluder = shape
		occluder.visibility_layer |= RECEIVER_LAYER # Culled like sprites otherwise
		occluder.occluder_light_mask = RECEIVER_LAYER
		holder.add_child(occluder)

# Moves a light to its owner's feet (their collision box), not the middle of the sprite:
# walls stop the feet at their edge, but the sprite's middle can be over a wall, and a light
# inside an occluder is cut off.
func _put_at_feet(light: PointLight2D, owner_node: Node) -> void:
	var feet := owner_node.get_node_or_null("CollisionShape2D") as Node2D
	if feet != null:
		light.position = feet.position

func _add_light(owner_node: Node, kind: Kind, color: Color) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = LIGHT_NAME
	light.texture = light_texture()
	# The project samples textures nearest-pixel for crisp sprites; a light stretched that way
	# shows its texels as steps, so lights blend between them instead.
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.color = color
	# Hard-edged shadows: the light map steps them in whole game pixels, which a soft
	# filter would only blur.
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	light.set_meta(&"kind", kind)
	light.visibility_layer |= RECEIVER_LAYER # Or the light map's viewport culls it
	owner_node.add_child.call_deferred(light)
	light.ready.connect(_apply_light.bind(light), CONNECT_ONE_SHOT)
	return light

func _on_tuning_changed(key: String) -> void:
	if key.begins_with("light") || key == "cave_brightness":
		_apply_all()

func _apply_all() -> void:
	_receiver.color = ambient_color() * LIGHT_MAP_SCALE
	_receiver.color.a = 1.0
	_overlay.visible = Tuning.lighting_enabled
	for light in get_parent().find_children(LIGHT_NAME, "PointLight2D", true, false):
		_apply_light(light as PointLight2D)

func _apply_light(light: PointLight2D) -> void:
	var radius: float
	match int(light.get_meta(&"kind")):
		Kind.PLAYER:
			radius = Tuning.light_player_radius
			light.energy = Tuning.light_player_energy
		Kind.KNIGHT:
			radius = Tuning.light_knight_radius
			light.energy = Tuning.light_knight_energy
		_:
			radius = Tuning.light_projectile_radius
			light.energy = Tuning.light_small_energy
	light.energy *= (1.0 - _brightness_lift) * LIGHT_MAP_SCALE
	light.range_item_cull_mask = RECEIVER_LAYER # Lights only reach the light map
	# A shadow only falls on items, and comes only from occluders, sharing this mask.
	light.shadow_item_cull_mask = RECEIVER_LAYER
	light.enabled = Tuning.lighting_enabled
	light.shadow_enabled = Tuning.light_shadows
	# The texture's radius is half its width; undo any scale the owner has.
	var parent_scale := (light.get_parent() as Node2D).global_scale.x if light.get_parent() is Node2D else 1.0
	light.texture_scale = radius * 2.0 / TEXTURE_SIZE / maxf(absf(parent_scale), 0.01)
