class_name HudFrame
extends RefCounted

# The frame the minimap, item bar and shop share, drawn in code: a dark backing with a grey
# rim whose corner pixels are notched off, and a black line outside that follows the notches
# round. Rectangles are in art pixels; `unit` is how many of the canvas's own pixels one art
# pixel takes (1 on the 5x HudLayer, 5 on an unscaled screen-sized layer), so every edge
# lands on the same chunky pixel grid as the rest of the HUD art.

const Minimap := preload("res://src/ui/hud/Minimap.gd")

# The backing round `rect`, filled with `fill` (the minimap's translucent dark by default).
static func backing(canvas: CanvasItem, rect: Rect2, unit := 1.0, fill := Minimap.BACKING) -> void:
	var p := rect.position
	var e := rect.end
	var w := rect.size.x
	var h := rect.size.y
	_cell(canvas, rect.grow(-1), unit, fill)
	for strip: Rect2 in [Rect2(p.x + 1, p.y, w - 2, 1), Rect2(p.x + 1, e.y - 1, w - 2, 1),
			Rect2(p.x, p.y + 1, 1, h - 2), Rect2(e.x - 1, p.y + 1, 1, h - 2)]:
		_cell(canvas, strip, unit, Minimap.BORDER)
	for strip: Rect2 in [Rect2(p.x, p.y - 1, w, 1), Rect2(p.x, e.y, w, 1),
			Rect2(p.x - 1, p.y, 1, h), Rect2(e.x, p.y, 1, h)]:
		_cell(canvas, strip, unit, Minimap.OUTER)
	for corner: Vector2 in [p, Vector2(e.x - 1, p.y), Vector2(p.x, e.y - 1), e - Vector2.ONE]:
		_cell(canvas, Rect2(corner, Vector2.ONE), unit, Minimap.OUTER)

# A one-pixel outline inside `rect`, drawn as filled strips: draw_rect's own outline is
# centred on the edge, which would put it on half pixels and blur it.
static func outline(canvas: CanvasItem, rect: Rect2, color: Color, unit := 1.0) -> void:
	var p := rect.position
	var s := rect.size
	_cell(canvas, Rect2(p, Vector2(s.x, 1)), unit, color)
	_cell(canvas, Rect2(p.x, rect.end.y - 1, s.x, 1), unit, color)
	_cell(canvas, Rect2(p.x, p.y + 1, 1, s.y - 2), unit, color)
	_cell(canvas, Rect2(rect.end.x - 1, p.y + 1, 1, s.y - 2), unit, color)

# A rectangle given in art pixels, filled.
static func fill(canvas: CanvasItem, rect: Rect2, color: Color, unit := 1.0) -> void:
	_cell(canvas, rect, unit, color)

static func _cell(canvas: CanvasItem, rect: Rect2, unit: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position * unit, rect.size * unit), color)
