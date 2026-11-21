extends RichTextLabel

# Shows the time left on the player's level countdown, as m:ss, rounded up so it reads
# 0:00 exactly when time runs out.
#
# It sits at the top middle of the HUD. There's no health: damage takes time off instead
# (Player.lose_time), and the timer shows it: it flashes red, jolts and drains quickly down
# to the new time with a run of fast, falling ticks, while the time lost floats off below.
#
# For the last FINAL_SECONDS the timer slides down to the middle of the screen, grows and
# turns red, and every second ticks with a rising blip and a punch.
#
# A hit that takes more time than is left is shown in full (the game runs in slow motion
# meanwhile; see Player.lose_time): the timer slides to the middle, ticks rapidly down to
# 0:00, lands with a punch, and holds there with the game frozen before the game over.

const FINAL_SECONDS := 5
const FINAL_SCALE := 3.5 # Size in the middle, relative to its size at the top
const FINAL_COLOR := Color(1, 0.15, 0.15)
const SLIDE_TIME := 0.5
const PUNCH_SCALE := 1.25 # Extra growth on each tick, settling back over PUNCH_TIME
const PUNCH_TIME := 0.25
const TickSound := preload("res://assets/sfx/countdown_tick.wav")
const TICK_PITCH_STEP := 0.1 # Each tick is this much higher than the one before
# Losing time to damage (see the top of the file). Times are real seconds, so hit-stop
# doesn't hold the animation up.
const HURT_COLOR := Color(1, 0.2, 0.2)
const GAIN_COLOR := Color(0.2, 1.0, 0.2) # Time added, e.g. by a chest key
const DRAIN_TIME_PER_SECOND := 0.03 # The drain takes longer the more time is lost...
const DRAIN_TIME_MIN := 0.25
const DRAIN_TIME_MAX := 0.8 # ...within these
const DRAIN_TICK_GAP := 0.035 # Least time between drain ticks
const DRAIN_TICK_PITCH_START := 1.9 # The ticks fall from this pitch...
const DRAIN_TICK_PITCH_END := 1.2 # ...to this as the drain finishes
const DRAIN_TICK_DB := -4.0
const DRAIN_TICK_VOICES := 3 # Tick players to rotate through, so quick ticks don't cut off
const HURT_PUNCH := 1.25 # Extra size the timer jumps to when hit
const HURT_SHAKE := 1.5 # HUD pixels it jolts
const HURT_SHAKE_STEPS := 5
const FLOAT_OFFSET := Vector2(0, 17) # Where a floating time change starts, below the timer
const FLOAT_SCALE := 0.5 # Its size, relative to the timer's
const FLOAT_DRIFT := Vector2(0, 8) # How far it drifts down as it fades
const FLOAT_HOLD := 0.35 # Seconds before it starts to fade...
const FLOAT_FADE := 0.6 # ...and how long it takes
# A killing hit (see the top of the file).
const FATAL_DRAIN := 1.0 # Seconds to tick down to 0:00
const FATAL_TICK_PITCH_START := 1.7
const FATAL_TICK_PITCH_END := 0.8 # Lower than a hurt's drain, sinking as it lands
const FATAL_LAND_PUNCH := 1.45 # Extra size it jumps to on reaching 0:00
const FATAL_LAND_PITCH := 0.55 # The landing tick, low and heavy
const FATAL_HOLD := 1.0 # Seconds frozen on 0:00 before the game over

@onready var holder: Node2D = get_parent() # Marker the label hangs off; moved and scaled
@onready var corner_position := holder.position
@onready var corner_scale := holder.scale

var _shown := -1 # Seconds currently displayed
var _final := false # In the last-seconds display
var _tick: AudioStreamPlayer
var _tween: Tween
var _hurt_tween: Tween # The flash and punch of losing time
var _jolt_tween: Tween # ...and the jolt
var _drain_voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _draining := false
var _drain_from := 0.0 # Seconds shown when the drain started
var _drain_start_ms := 0
var _drain_length := 0.0
var _last_drain_tick_ms := 0
var _floaters: Array[Node2D] = [] # Floating time changes still on screen
var _fatal := false # Showing a killing hit
var _drain_pitch_start := DRAIN_TICK_PITCH_START
var _drain_pitch_end := DRAIN_TICK_PITCH_END

func _ready() -> void:
	# Running out of time pauses the game, so keep updating to show 0:00 under it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tick = AudioStreamPlayer.new()
	_tick.bus = &"SFX"
	_tick.stream = TickSound
	add_child(_tick)
	for i in DRAIN_TICK_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		voice.stream = TickSound
		voice.volume_db = DRAIN_TICK_DB
		add_child(voice)
		_drain_voices.append(voice)
	Game.player_died.connect(_on_player_died)
	Game.time_lost.connect(_on_time_lost)
	Game.time_gained.connect(_on_time_gained)

func _process(_delta: float) -> void:
	if Game.player == null:
		return
	if _fatal && !_draining:
		return # Holding: the old time while sliding to the middle, then 0:00
	var countdown: Timer = Game.player.level_countdown
	var value := countdown.time_left
	var draining := _draining
	if draining:
		var t := _drain_progress()
		value = lerpf(_drain_from, countdown.time_left, ease(t, 0.6)) # Fast, then settling
		if t >= 1.0:
			_draining = false
	var seconds := ceili(value)
	if seconds == _shown:
		return
	_shown = seconds
	@warning_ignore("integer_division")
	set_text("%d:%02d" % [seconds / 60, seconds % 60])
	if draining:
		_drain_tick()
		if _draining:
			return # The final-seconds display waits for the drain to land
	if _fatal:
		return # _show_fatal runs the display from here

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
	_kill_hurt_tweens()
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
	_kill_hurt_tweens()
	_final = false
	_set_alignment(HORIZONTAL_ALIGNMENT_CENTER)
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
	_kill_hurt_tweens()
	_fatal = false
	_draining = false
	holder.visible = false
	# A floating time change would hang frozen over the game over and upgrade menu.
	for floater in _floaters:
		if is_instance_valid(floater):
			floater.queue_free()
	_floaters.clear()

# --- Losing time to damage ---

# Called just before the time comes off, so the drain starts from what's on screen now.
func _on_time_lost(seconds: float, fatal: bool) -> void:
	if fatal:
		_show_fatal()
		return
	_start_drain(clampf(seconds * DRAIN_TIME_PER_SECOND, DRAIN_TIME_MIN, DRAIN_TIME_MAX),
		DRAIN_TICK_PITCH_START, DRAIN_TICK_PITCH_END)
	_float_loss(roundi(seconds))

	_kill_hurt_tweens()
	var settle := _drain_length + 0.15
	_hurt_tween = create_tween().set_ignore_time_scale().set_parallel()
	# Red, fading back to its usual colour as the drain lands.
	modulate = HURT_COLOR
	_hurt_tween.tween_property(self, "modulate", FINAL_COLOR if _final else Color.WHITE, settle) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _final:
		return # The final-seconds display owns the timer's size and place
	holder.scale = corner_scale * HURT_PUNCH
	_hurt_tween.tween_property(holder, "scale", corner_scale, settle) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_jolt_tween = create_tween().set_ignore_time_scale()
	var step_time := settle / (HURT_SHAKE_STEPS + 1)
	for i in HURT_SHAKE_STEPS:
		var size := HURT_SHAKE * (1.0 - float(i) / HURT_SHAKE_STEPS) # Dying down
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * size
		_jolt_tween.tween_property(holder, "position", corner_position + offset, step_time)
	_jolt_tween.tween_property(holder, "position", corner_position, step_time)

# Time added (e.g. a chest hourglass): stop any drain so the display doesn't count up
# through the falling ticks, flash green, and show the amount gained.
func _on_time_gained(seconds: float) -> void:
	_draining = false
	_kill_hurt_tweens()
	modulate = GAIN_COLOR
	var flash := create_tween().set_ignore_time_scale()
	flash.tween_property(self, "modulate", FINAL_COLOR if _final else Color.WHITE, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_float_gain(roundi(seconds))

# Counts the display down from what it shows now to the countdown's time, over `length`
# real seconds, ticking from `pitch_start` to `pitch_end` (see _process and _drain_tick).
func _start_drain(length: float, pitch_start: float, pitch_end: float) -> void:
	_drain_from = float(_shown) if _draining else Game.player.level_countdown.time_left
	_drain_start_ms = Time.get_ticks_msec()
	_drain_length = length
	_drain_pitch_start = pitch_start
	_drain_pitch_end = pitch_end
	_draining = true

# A killing hit, start to finish: to the middle, tick down to 0:00, land, hold frozen,
# then tell the player to die (Game.fatal_countdown_finished).
func _show_fatal() -> void:
	_fatal = true
	var from := float(_shown) if _shown >= 0 else Game.player.level_countdown.time_left
	if !_final:
		_enter_final()
		await _tween.finished
	_draining = false
	_shown = ceili(from)
	_start_drain(FATAL_DRAIN, FATAL_TICK_PITCH_START, FATAL_TICK_PITCH_END)
	_drain_from = from
	# Each wait checks the timer is still in the game: leaving it mid-countdown (F1 back to the
	# room creator from a play-test) takes it out of the tree, and there's nothing to finish.
	while _draining:
		if !is_inside_tree():
			return
		await get_tree().process_frame
	if !is_inside_tree():
		return
	_land_fatal()
	Juice.hitstop(FATAL_HOLD) # The world freezes with it
	await get_tree().create_timer(FATAL_HOLD, true, false, true).timeout
	if !is_inside_tree():
		return
	Game.fatal_countdown_finished.emit()

# 0:00: a heavy tick, a punch in size, a flash and a shake.
func _land_fatal() -> void:
	Juice.play(_tick, 0.0, FATAL_LAND_PITCH)
	Juice.shake(Juice.SHAKE_HEAVY)
	var punch := create_tween().set_ignore_time_scale()
	punch.tween_method(_set_final_size, FATAL_LAND_PUNCH, 1.0, PUNCH_TIME * 2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modulate = Color.WHITE
	punch.parallel().tween_property(self, "modulate", FINAL_COLOR, PUNCH_TIME * 2)

# How far through the drain, 0 to 1, in real time.
func _drain_progress() -> float:
	return clampf((Time.get_ticks_msec() - _drain_start_ms) / 1000.0 / _drain_length, 0.0, 1.0)

# One fast tick of the drain, falling in pitch as it goes. Kept a little apart, however
# many seconds go by in a frame.
func _drain_tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_drain_tick_ms < DRAIN_TICK_GAP * 1000.0:
		return
	_last_drain_tick_ms = now
	var voice := _drain_voices[_next_voice]
	_next_voice = (_next_voice + 1) % _drain_voices.size()
	Juice.play(voice, 0.03, lerpf(_drain_pitch_start, _drain_pitch_end, _drain_progress()))

# "-0:10" in red, just under the timer, drifting down and fading.
func _float_loss(seconds: int) -> void:
	_float_change(seconds, "-", HURT_COLOR)

# "+0:30" in green when time is added, mirroring a loss.
func _float_gain(seconds: int) -> void:
	_float_change(seconds, "+", GAIN_COLOR)

func _float_change(seconds: int, prefix: String, color: Color) -> void:
	var marker := Node2D.new()
	marker.position = corner_position + FLOAT_OFFSET
	marker.scale = corner_scale * FLOAT_SCALE
	var label := Label.new()
	label.add_theme_font_override("font", get_theme_font("normal_font"))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 30)
	label.position = Vector2(-80, 0)
	@warning_ignore("integer_division")
	label.text = "%s%d:%02d" % [prefix, seconds / 60, seconds % 60]
	marker.add_child(label)
	holder.get_parent().add_child(marker)
	_floaters.append(marker)
	marker.tree_exited.connect(_floaters.erase.bind(marker))
	var fade := marker.create_tween().set_ignore_time_scale()
	fade.tween_interval(FLOAT_HOLD)
	fade.tween_property(marker, "position", marker.position + FLOAT_DRIFT, FLOAT_FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.parallel().tween_property(marker, "modulate:a", 0.0, FLOAT_FADE)
	fade.tween_callback(marker.queue_free)

# Stops the hurt animation, putting the timer back in its place unless the final-seconds
# display has it.
func _kill_hurt_tweens() -> void:
	for tween in [_hurt_tween, _jolt_tween]:
		if tween != null && tween.is_valid():
			tween.kill()
	_hurt_tween = null
	_jolt_tween = null
	if !_final:
		holder.position = corner_position
		holder.scale = corner_scale

func _restart_tween() -> void:
	if _tween != null:
		_tween.kill()
	# Real time, so slow motion and hit-stop don't drag the slides out.
	_tween = create_tween().set_parallel().set_ignore_time_scale()

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
