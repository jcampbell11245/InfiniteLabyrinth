class_name CaveLighting
extends Node

# Darkens the cave and lights it with a few soft 2D lights. Overworld adds one to every
# floor. A CanvasModulate dims everything drawn on the world canvas (the HUD sits on its own
# CanvasLayers, so it stays bright), and PointLight2Ds add light back: a warm one carried by
# the player, and small coloured ones on fireballs, lasers and dropped arrows so they stand
# out in the dark. Coins don't glow. Lights are attached as nodes spawn, so nothing else needs to know about
# lighting. Every number is in Tuning (the F2 menu's Lighting tab) and applies live.
#
# The start and end rooms stay fully lit: walking into one fades the darkness (and the
# lights, which would only wash it out) away, and walking out brings them back.

const LIGHT_NAME := &"CaveLight"
const ARROW_PICKUP_SCRIPT := preload("res://src/effects/ArrowPickup.gd")
# Projectile scenes that glow; arrows don't.
const GLOWING_PROJECTILES := ["Fireball", "Laser"]
# Pixels across the generated light texture. Big, because the player's light stretches it
# over most of a room and coarse texels show up as rings.
const TEXTURE_SIZE := 512
const FALLOFF_STOPS := 32 # Gradient points along the falloff curve; few points show as bands

const PLAYER_COLOR := Color(1.0, 0.86, 0.62) # Torch-warm
const FIREBALL_COLOR := Color(1.0, 0.55, 0.2)
const LASER_COLOR := Color(1.0, 0.3, 0.3)
const PICKUP_COLOR := Color(1.0, 0.9, 0.5)

enum Kind { PLAYER, PROJECTILE, PICKUP }

const BRIGHT_ROOMS := [Constants.START_ROOM, Constants.END_ROOM]
const BRIGHT_FADE_TIME := 0.5 # Real seconds the darkness takes to lift or fall on changing rooms

var _darkness: CanvasModulate
var _texture: GradientTexture2D
var _brightness_lift := 0.0 # 0 in the dark cave, 1 in a room kept fully lit
var _lift_tween: Tween
var _seen_room := false # The first room is set at once, not faded to

func _ready() -> void:
	_darkness = CanvasModulate.new()
	_darkness.name = "Darkness"
	add_child(_darkness)
	get_tree().node_added.connect(_on_node_added)
	Tuning.changed.connect(_on_tuning_changed)
	Game.room_entered.connect(_on_room_entered)
	# Light what already exists on the floor (the player is in it before this runs).
	for node in get_parent().find_children("*", "", true, false):
		_on_node_added(node)
	_apply_all()

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

# The colour the unlit cave is multiplied by: Tuning.cave_brightness in every channel,
# nudged towards blue so the shadows read as cold stone rather than grey, and blended to
# white as a bright room's lift comes in.
func ambient_color() -> Color:
	if !Tuning.lighting_enabled:
		return Color.WHITE
	var b := Tuning.cave_brightness
	return Color(b * 0.85, b * 0.9, b * 1.1).clamp().lerp(Color.WHITE, _brightness_lift)

func _on_room_entered(room_id: int) -> void:
	var target := 1.0 if room_id in BRIGHT_ROOMS else 0.0
	if _lift_tween != null:
		_lift_tween.kill()
	if !_seen_room:
		_seen_room = true
		_set_lift(target)
		return
	_lift_tween = create_tween().set_ignore_time_scale()
	_lift_tween.tween_method(_set_lift, _brightness_lift, target, BRIGHT_FADE_TIME)

func _set_lift(value: float) -> void:
	_brightness_lift = value
	_apply_all()

func _on_node_added(node: Node) -> void:
	if node.has_node(NodePath(LIGHT_NAME)):
		return
	if node is Player:
		_add_light(node, Kind.PLAYER, PLAYER_COLOR)
	elif node is Projectile:
		var scene := node.scene_file_path.get_file().get_basename()
		if scene in GLOWING_PROJECTILES:
			_add_light(node, Kind.PROJECTILE, LASER_COLOR if scene == "Laser" else FIREBALL_COLOR)
	elif node.get_script() == ARROW_PICKUP_SCRIPT:
		_add_light(node, Kind.PICKUP, PICKUP_COLOR)

func _add_light(owner_node: Node, kind: Kind, color: Color) -> void:
	var light := PointLight2D.new()
	light.name = LIGHT_NAME
	light.texture = light_texture()
	# The project samples textures nearest-pixel for crisp sprites; a light stretched that way
	# shows its texels as steps, so lights blend between them instead.
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.color = color
	light.set_meta(&"kind", kind)
	owner_node.add_child.call_deferred(light)
	light.ready.connect(_apply_light.bind(light), CONNECT_ONE_SHOT)

func _on_tuning_changed(key: String) -> void:
	if key.begins_with("light") || key == "cave_brightness":
		_apply_all()

func _apply_all() -> void:
	_darkness.color = ambient_color()
	for light in get_parent().find_children(LIGHT_NAME, "PointLight2D", true, false):
		_apply_light(light as PointLight2D)

func _apply_light(light: PointLight2D) -> void:
	var radius: float
	match int(light.get_meta(&"kind")):
		Kind.PLAYER:
			radius = Tuning.light_player_radius
			light.energy = Tuning.light_player_energy
		Kind.PROJECTILE:
			radius = Tuning.light_projectile_radius
			light.energy = Tuning.light_small_energy
		_:
			radius = Tuning.light_pickup_radius
			light.energy = Tuning.light_small_energy
	light.energy *= 1.0 - _brightness_lift
	light.enabled = Tuning.lighting_enabled
	# The texture's radius is half its width; undo any scale the owner has.
	var parent_scale := (light.get_parent() as Node2D).global_scale.x if light.get_parent() is Node2D else 1.0
	light.texture_scale = radius * 2.0 / TEXTURE_SIZE / maxf(absf(parent_scale), 0.01)
