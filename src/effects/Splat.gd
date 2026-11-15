extends Node2D

# A permanent floor stain left where an enemy died: a blob of chunky pixels in `color`,
# drawn once. Sits on the floor tiles and below everything standing on them (z 1 and up).

const PIXEL := 1.0

var color := Color(0.5, 0.05, 0.05)
var radius := 9.0
# Takes a global point and returns false where the stain mustn't show (pits, walls).
# Pieces landing there are dropped. Empty keeps every piece.
var is_floor := Callable()

var _rects: Array[Rect2] = []
var _shades: Array[Color] = []

func _ready() -> void:
	z_index = 0 # Floor tiles are at 0 or below; added after them, so drawn on top
	# Rounded to whole pixels so it matches the pixel art.
	var pieces := int(radius * 4)
	for i in pieces:
		# Biased towards the middle: dense core, ragged edges.
		var dist := radius * pow(randf(), 1.6)
		var offset := Vector2.from_angle(randf() * TAU) * dist
		offset.y *= 0.6 # Squashed, since the floor is seen at an angle
		var size := PIXEL * randi_range(1, 3)
		var rect := Rect2(offset.round(), Vector2(size, size))
		if is_floor.is_valid() && !is_floor.call(to_global(rect.get_center())):
			continue
		_rects.append(rect)
		_shades.append(color.darkened(randf_range(0.0, 0.25)))
	queue_redraw()

func _draw() -> void:
	for i in _rects.size():
		draw_rect(_rects[i], _shades[i])
