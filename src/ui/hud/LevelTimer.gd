extends RichTextLabel

# Shows the time left on the player's level countdown, as m:ss, rounded up so it reads
# 0:00 exactly when time runs out.
#
# For the last FINAL_SECONDS the timer slides from its corner to the middle of the
# screen, grows and turns red, and every second ticks with a rising blip and a punch.

const FINAL_SECONDS := 5
const FINAL_SCALE := 3.0 # Size in the middle, relative to its corner size
const FINAL_COLOR := Color(1, 0.15, 0.15)
const SLIDE_TIME := 0.5
const PUNCH_SCALE := 1.25 # Extra growth on each tick, settling back over PUNCH_TIME
const PUNCH_TIME := 0.25
const TickSound := preload("res://assets/sfx/countdown_tick.wav")
const TICK_PITCH_STEP := 0.1 # Each tick is this much higher than the one before

@onready var holder: Node2D = get_parent() # Marker the label hangs off; moved and scaled
@onready var corner_position := holder.position
@onready var corner_scale := holder.scale

var _shown := -1 # Seconds currently displayed
var _final := false # In the last-seconds display
var _tick: AudioStreamPlayer
var _tween: Tween

func _ready() -> void:
	# Running out of time pauses the game, so keep updating to show 0:00 under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tick = AudioStreamPlayer.new()
	_tick.stream = TickSound
	add_child(_tick)
	Game.player_died.connect(_on_player_died)

func _process(_delta: float) -> void:
	if Game.player == null:
		return
	var countdown: Timer = Game.player.level_countdown
	var seconds := ceili(countdown.time_left)
	if seconds == _shown:
		return
	_shown = seconds
	@warning_ignore("integer_division")
	set_text("%d:%02d" % [seconds / 60, seconds % 60])

	var in_final := !countdown.is_stopped() && seconds > 0 && seconds <= FINAL_SECONDS
	if in_final && !_final:
		_enter_final()
	elif !in_final && _final && seconds > FINAL_SECONDS:
		_leave_final()
	if in_final:
		_tick_second(seconds)

# Slides to the middle of the screen, grows and turns red. The text switches to centre
# alignment first (moving the holder so nothing jumps), so narrower times like 0:01
# stay centred instead of drifting right.
func _enter_final() -> void:
	_final = true
	_set_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	_restart_tween()
	_tween.tween_property(holder, "position", _centre_position(), SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(holder, "scale", corner_scale * FINAL_SCALE, SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", FINAL_COLOR, SLIDE_TIME * 0.5)

# Back to normal, in case time is ever added back during the final seconds.
func _leave_final() -> void:
	_final = false
	_set_alignment(HORIZONTAL_ALIGNMENT_RIGHT)
	_restart_tween()
	_tween.tween_property(holder, "position", corner_position, SLIDE_TIME)
	_tween.tween_property(holder, "scale", corner_scale, SLIDE_TIME)
	_tween.tween_property(self, "modulate", Color.WHITE, SLIDE_TIME)

# One second gone: a blip that climbs as time runs out, a punch in size and a flash.
func _tick_second(seconds: int) -> void:
	var step := FINAL_SECONDS - seconds # 0 on the first tick
	Juice.play(_tick, 0.0, 1.0 + TICK_PITCH_STEP * step)
	Juice.shake(Juice.SHAKE_LIGHT if seconds > 1 else Juice.SHAKE_MEDIUM)
	# The first tick happens as the slide starts, so let the slide handle the size.
	if step == 0:
		return
	var punch := create_tween()
	punch.tween_method(_set_final_size, PUNCH_SCALE, 1.0, PUNCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modulate = Color.WHITE
	punch.parallel().tween_property(self, "modulate", FINAL_COLOR, PUNCH_TIME)

# The game-over text takes over the screen, so the timer gets out of its way.
func _on_player_died() -> void:
	if _tween != null:
		_tween.kill()
	holder.visible = false

func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()

# Changes the text alignment and moves the holder by the same amount the other way,
# so the text stays exactly where it was on screen.
func _set_alignment(alignment: HorizontalAlignment) -> void:
	var before := _text_centre()
	horizontal_alignment = alignment
	holder.position += (before - _text_centre()) * holder.scale

# Sets the final-seconds size, `factor` times FINAL_SCALE, growing around the middle of
# the screen rather than the holder's corner.
func _set_final_size(factor: float) -> void:
	holder.scale = corner_scale * FINAL_SCALE * factor
	holder.position = _screen_centre_in_parent() - _text_centre() * holder.scale

# Where the holder must sit, at FINAL_SCALE, for the text to be centred on screen.
func _centre_position() -> Vector2:
	return _screen_centre_in_parent() - _text_centre() * corner_scale * FINAL_SCALE

func _screen_centre_in_parent() -> Vector2:
	var parent := holder.get_parent() as CanvasItem
	return parent.get_global_transform_with_canvas().affine_inverse() \
		* (get_viewport_rect().size / 2)

# Middle of the text in the holder's space, which depends on the alignment: right-
# aligned text ends at the label's right edge, centred text sits mid-label.
func _text_centre() -> Vector2:
	var y := offset_top + get_content_height() / 2.0
	if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		return Vector2((offset_left + offset_right) / 2.0, y)
	return Vector2(offset_right - get_content_width() / 2.0, y)
