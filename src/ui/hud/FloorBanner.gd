class_name FloorBanner
extends CanvasLayer

# A message across the top of the screen as a floor starts, telling the player that gold
# floor servers (see Server.make_floor_server) are boosting every enemy on it, and what they
# boost. It fades in, stays SHOW_TIME seconds and fades out, in real time so hit-stop
# doesn't stretch it. Overworld shows it once the floor is built.

const AlertSound := preload("res://assets/sfx/server_alert.wav")
const DELAY := 0.6 # Seconds after the floor starts, once the first room has faded in
const FADE_IN := 0.35
const SHOW_TIME := 3.0
const FADE_OUT := 0.6
const TOP := 130.0 # Screen pixels from the top, clear of the level timer
const TITLE_SIZE := 40
const TEXT_SIZE := 28
const GOLD := Color(1.0, 0.84, 0.3)
const BACKING := Color(0, 0, 0, 0.6)
const PADDING := Vector2(36, 18)
const ALERT_VOLUME_DB := -6.0

# Shows the banner over `parent` for the floor servers `gold`.
static func show_for(parent: Node, gold: Array[Server]) -> FloorBanner:
	var banner := FloorBanner.new()
	banner.text = describe(gold)
	parent.add_child(banner)
	return banner

# What the banner says about `gold`: which boosts they spread, in words.
static func describe(gold: Array[Server]) -> String:
	var boosts: PackedStringArray = []
	var swapping := false
	for server in gold:
		if server.buff == ServerBuff.RANDOM_SWAP:
			swapping = true
			continue
		var name: String = ServerBuff.NAMES[server.kind]
		if !boosts.has(name):
			boosts.append(name)
	if swapping:
		boosts.append("ever-changing")
	var what := " and ".join(boosts) if boosts.size() <= 2 \
		else ", ".join(boosts.slice(0, boosts.size() - 1)) + " and " + boosts[boosts.size() - 1]
	var count := "A gold server is" if gold.size() == 1 else "%d gold servers are" % gold.size()
	return "%s boosting enemy %s across this floor.\nDestroy %s to end it." \
		% [count, what, "it" if gold.size() == 1 else "them"]

var text := ""

func _ready() -> void:
	layer = 20 # Over the HUD
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKING
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := _label("FLOOR SERVERS ONLINE", TITLE_SIZE, GOLD)
	column.add_child(title)
	column.add_child(_label(text, TEXT_SIZE, Color.WHITE))
	# Centred across the top of the screen, below the level timer.
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = TOP
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	add_child(holder)
	panel.modulate.a = 0.0

	var tween := create_tween().set_ignore_time_scale()
	tween.tween_interval(DELAY)
	tween.tween_callback(_play_alert)
	tween.tween_property(panel, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(SHOW_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)

func _label(words: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label

func _play_alert() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = AlertSound
	sound.bus = &"SFX"
	sound.volume_db = ALERT_VOLUME_DB
	add_child(sound)
	sound.play()
