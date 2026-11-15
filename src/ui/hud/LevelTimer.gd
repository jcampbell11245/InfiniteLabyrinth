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

# Slides to the middle of the screen, grows and turns red.
func _enter_final() -> void:
	_final = true
	_restart_tween()
	_tween.tween_property(holder, "position", _centre_position(), SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(holder, "scale", corner_scale * FINAL_SCALE, SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", FINAL_COLOR, SLIDE_TIME * 0.5)

# Back to normal, in case time is ever added back during the final seconds.
func _leave_final() -> void:
	_final = false
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
	holder.scale = corner_scale * FINAL_SCALE * PUNCH_SCALE
	punch.tween_property(holder, "scale", corner_scale * FINAL_SCALE, PUNCH_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modulate = Color.WHITE
	punch.parallel().tween_property(self, "modulate", FINAL_COLOR, PUNCH_TIME)

func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()

# Where the holder must sit, at FINAL_SCALE, for the text to be centred on screen. The
# text is right-aligned inside the label, so its middle is half its width from the
# label's right edge.
func _centre_position() -> Vector2:
	var screen_centre := get_viewport_rect().size / 2
	var parent := holder.get_parent() as CanvasItem
	var centre_in_parent := parent.get_global_transform_with_canvas().affine_inverse() * screen_centre
	var text_centre := Vector2(offset_right - get_content_width() / 2.0,
		offset_top + get_content_height() / 2.0)
	return centre_in_parent - text_centre * corner_scale * FINAL_SCALE
