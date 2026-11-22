class_name ButtonPrompt
extends Node2D

# A button glyph floating over something the player can interact with (see Merchant),
# bobbing gently. It shows `glyph` for whatever device the player last touched
# (InputGlyphs), drawn in world pixels and centred on this node.

const BOB_HEIGHT := 1.0 # World pixels up and down
const BOB_PERIOD := 0.9 # Seconds per bob, in real time

@export var glyph := InputGlyphs.Glyph.CONFIRM

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	if visible:
		queue_redraw() # The bob, and the device can change at any time

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob := roundf(sin(t * TAU / BOB_PERIOD) * BOB_HEIGHT)
	var size := Vector2(InputGlyphs.width(glyph), InputGlyphs.SIZE)
	InputGlyphs.draw(self, glyph, (-size / 2.0).floor() + Vector2(0, bob))
