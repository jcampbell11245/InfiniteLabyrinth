class_name FloorBanner
extends CanvasLayer

# A message across the top of the screen as a floor starts, telling the player that premium
# servers (silver floor servers, see Server.make_floor_server) are boosting every enemy on it,
# and what they boost, in the pixel font of the title screen and menus. It fades in, stays
# SHOW_TIME seconds and fades out, in real time so hit-stop doesn't stretch it. Overworld
# shows it once the floor is built.

const AlertSound := preload("res://assets/sfx/server_alert.wav")
const PIXEL_FONT := preload("res://assets/fonts/8-BIT WONDER.TTF")
const DELAY := 0.6 # Seconds after the floor starts, once the first room has faded in
const FADE_IN := 0.35
const SHOW_TIME := 3.0
const FADE_OUT := 0.6
const TOP := 130.0 # Screen pixels from the top, clear of the level timer
const TITLE_SIZE := 32 # The pixel font is wide: whole multiples of 8 keep it crisp
const TEXT_SIZE := 24
const SILVER := Color(0.86, 0.9, 0.97) # The premium servers' own colour
const BACKING := Color(0, 0, 0, 0.6)
const PADDING := Vector2(36, 18)
const LINE_GAP := 10 # Between the title and the message
const MESSAGE_WIDTH := 1300.0 # Screen pixels the message wraps at, well inside the 1920 screen
const MESSAGE_LINE_SPACING := 8 # Extra pixels between wrapped lines, so their outlines don't touch
const ALERT_VOLUME_DB := -6.0

# Shows the banner over `parent` for the premium servers `premium`.
static func show_for(parent: Node, premium: Array[Server]) -> FloorBanner:
	var banner := FloorBanner.new()
	banner.text = describe(premium)
	parent.add_child(banner)
	return banner

# What the banner says about `premium`: which boosts they spread, in words.
static func describe(premium: Array[Server]) -> String:
	var boosts: PackedStringArray = []
	var swapping := false
	for server in premium:
		if server.buff == ServerBuff.RANDOM_SWAP:
			swapping = true
			continue
		var name: String = ServerBuff.NAMES[server.kind]
		if !boosts.has(name):
			boosts.append(name)
	var one := premium.size() == 1
	var count := "A premium server is" if one else "%d premium servers are" % premium.size()
	var what := "enemy " + _listed(boosts) if !boosts.is_empty() else "enemies"
	var lines: PackedStringArray = ["%s boosting %s across this floor." % [count, what]]
	# Swap servers' boosts keep changing, so they get a sentence of their own, not a kind.
	if swapping:
		if !boosts.is_empty():
			lines.append("Some keep changing their boosts.")
		else:
			lines.append("Its boost keeps changing." if one else "Their boosts keep changing.")
	lines.append("Destroy %s to end it." % ("it" if one else "them"))
	return " ".join(lines)

# "a", "a and b" or "a, b and c".
static func _listed(words: PackedStringArray) -> String:
	if words.size() <= 2:
		return " and ".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " and " + words[words.size() - 1]

var text := ""

func _ready() -> void:
	layer = 20 # Over the HUD
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKING
	style.border_color = SILVER
	style.set_border_width_all(3)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", LINE_GAP)
	panel.add_child(column)
	var title := _label("PREMIUM SERVERS ONLINE", TITLE_SIZE, SILVER)
	column.add_child(title)
	# The message wraps at MESSAGE_WIDTH: the pixel font is wide, and a floor whose premium
	# servers give several boosts makes a long line.
	var message := _label(text, TEXT_SIZE, Color.WHITE)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.x = MESSAGE_WIDTH
	message.add_theme_constant_override("line_spacing", MESSAGE_LINE_SPACING)
	column.add_child(message)
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
	label.add_theme_font_override("font", PIXEL_FONT)
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
