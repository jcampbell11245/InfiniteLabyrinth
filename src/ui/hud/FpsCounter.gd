extends CanvasLayer

# A frames-per-second readout in the bottom-right corner, above the minimap, shown while
# Tuning.show_fps is on (F2 menu, Display tab). DebugMenu adds one to the tree in debug
# builds, so it stays up across scene changes and over every menu, the debug menu too.
# It counts real frames, so hit-stop and pausing don't change what it reads.

const LAYER := 101 # Over the debug menu (100), so it can be watched while tuning
const FONT_SIZE := 28
const OUTLINE_SIZE := 6
const MARGIN := Vector2(24, 200) # From the bottom-right corner; clears the minimap and the
# debug menu's buttons, which sit at the top
const REFRESH_TIME := 0.25 # Real seconds between updates, so the number is readable

var _label: Label
var _since_refresh := 0.0

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position -= MARGIN
	add_child(_label)
	Tuning.changed.connect(_on_tuning_changed)
	_apply()

func _process(delta: float) -> void:
	if !visible:
		return
	# delta is scaled by Engine.time_scale; undo that so the refresh keeps real time.
	_since_refresh += delta / maxf(Engine.time_scale, 0.001)
	if _since_refresh >= REFRESH_TIME:
		_since_refresh = 0.0
		_refresh()

func _on_tuning_changed(key: String) -> void:
	if key == "show_fps":
		_apply()

func _apply() -> void:
	visible = Tuning.show_fps
	_refresh()

func _refresh() -> void:
	_label.text = "%d FPS" % Engine.get_frames_per_second()
