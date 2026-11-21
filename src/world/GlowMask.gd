class_name GlowMask
extends AnimatedSprite2D

# Makes part of a sprite glow in the dark (CaveLighting puts one on each knight, for its
# visor and sword). It's a copy of the sprite that shows only the glowing pixels
# (glow_mask.gdshader) and is drawn after the cave's darkness is applied, so those pixels
# keep their full colour. It follows the sprite's animation, frame and flip every frame,
# and fades with its room's black cover so it doesn't show through a faded-out room.

const SHADER := preload("res://src/world/glow_mask.gdshader")

var _source: AnimatedSprite2D
var _cover: ColorRect # The room's fade-to-black cover, if any

static func attach(source: AnimatedSprite2D) -> GlowMask:
	var glow := GlowMask.new()
	glow.name = "GlowMask"
	glow._source = source
	source.add_child(glow)
	return glow

func _ready() -> void:
	sprite_frames = _source.sprite_frames
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material
	light_mask = 0
	# Above the light overlay (CaveLighting draws it at the top z), so the darkness never
	# reaches these pixels.
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	process_priority = 100 # After the sprite has moved on to this frame's animation frame
	var node := get_parent()
	while node != null && !(node is Room):
		node = node.get_parent()
	if node != null:
		_cover = node.get_node_or_null("Void/ColorRect")
	_copy_source()

func _process(_delta: float) -> void:
	_copy_source()

func _copy_source() -> void:
	if animation != _source.animation:
		animation = _source.animation
	frame = _source.frame
	flip_h = _source.flip_h
	flip_v = _source.flip_v
	centered = _source.centered
	offset = _source.offset
	var shown := 1.0 if _cover == null || !_cover.visible else 1.0 - clampf(_cover.color.a, 0.0, 1.0)
	modulate.a = shown
	visible = Tuning.lighting_enabled && shown > 0.0
