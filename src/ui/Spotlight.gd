class_name Spotlight
extends CanvasLayer

# Darkens the whole screen except a circle round one point of the world, to point the
# player at something (the tutorial puts one on a parry star). Add it to the tree, then
# show_on(); hide_light() fades it out and frees it. It runs while the game is paused, so it
# can fade in over a frozen moment.

const LAYER := 49 # Over the HUD, under dialogue boxes (Merchant.SHOP_LAYER)
const RADIUS := 60.0 # Screen pixels
const FADE_TIME := 0.15 # Seconds, real time
const SHADER := preload("res://src/ui/spotlight.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial

func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)

# Lights the circle round `world_point` (a global position in the game world).
func show_on(world_point: Vector2) -> void:
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = size
	_material.set_shader_parameter("rect_size", size)
	_material.set_shader_parameter("centre", viewport.get_canvas_transform() * world_point)
	_material.set_shader_parameter("radius", RADIUS)
	create_tween().tween_property(_rect, "modulate:a", 1.0, FADE_TIME)

func hide_light() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
