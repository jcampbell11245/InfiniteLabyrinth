extends Node

# Game-feel helpers shared by the player, enemies and world: hit-stop, screen shake,
# pitch-varied sounds, sprite flashes and throwaway particle bursts. None of it needs
# sprites or sounds of its own; particles are plain coloured squares.

const FlashShader := preload("res://src/effects/flash.gdshader")
const Coin := preload("res://src/effects/CoinPickup.gd")
const ArrowPickup := preload("res://src/effects/ArrowPickup.gd")
const Splat := preload("res://src/effects/Splat.gd")
const Twinkle := preload("res://src/effects/Twinkle.gd")
const TWINKLE_SOUND := preload("res://assets/sfx/twinkle.wav")
const TWINKLE_VOLUME_DB := -6.0
const UNPARRYABLE_TWINKLE_PITCH := 0.7 # The red, unparryable twinkle's sound, pitched down
const UNPARRYABLE_TWINKLE_DETUNE := 1.06 # Its second voice, a little sharper, so the two beat
const Dizzy := preload("res://src/effects/Dizzy.gd")
const CLANK := preload("res://assets/sfx/clank1.wav")
# The clank pitched down, muffled and crushed: the player's swing was blocked.
const CLANK_BAD := preload("res://assets/sfx/clank_bad.wav")
# The wizard's fireball sound sent back the other way: a fireball batted back.
const DEFLECT := preload("res://assets/sfx/deflect.wav")

# Hit-stop slows the whole game to Tuning.hitstop_time_scale of normal speed rather than
# 0, so anything dividing by delta keeps working.

# Shake presets: [duration, frequency, amplitude]. Amplitude is in pixels before the
# display scale-up, so 1-3 is already plenty.
const SHAKE_LIGHT := [0.12, 30.0, 1.0]
const SHAKE_MEDIUM := [0.2, 30.0, 2.0]
const SHAKE_HEAVY := [0.3, 30.0, 3.0]

# Coin pickup: a random one of the ten coin sounds per coin. Coins that land close
# together climb in pitch, and ones landing within COIN_GAP of each other are merged.
const COIN_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sfx/coin/coin1.wav"), preload("res://assets/sfx/coin/coin2.wav"),
	preload("res://assets/sfx/coin/coin3.wav"), preload("res://assets/sfx/coin/coin4.wav"),
	preload("res://assets/sfx/coin/coin5.wav"), preload("res://assets/sfx/coin/coin6.wav"),
	preload("res://assets/sfx/coin/coin7.wav"), preload("res://assets/sfx/coin/coin8.wav"),
	preload("res://assets/sfx/coin/coin9.wav"), preload("res://assets/sfx/coin/coin10.wav"),
]
const COIN_GAP := 40 # Ms; a coin arriving sooner than this after the last makes no sound
const COIN_CHAIN := 400 # Ms; coins arriving within this of the last count as one chain
const COIN_PITCH_STEP := 0.05
const COIN_PITCH_MAX_STEPS := 6
const COIN_VOLUME_DB := -4.0
const COIN_VOICES := 4 # Players taken in turn, so a new coin doesn't cut off the last
# The coin sound pitched down and run backwards: a troll stealing coins.
const COIN_BAD := preload("res://assets/sfx/coin_bad.wav")

var _hitstop_until := 0 # Ticks (ms) when the current hit-stop ends; 0 when none
var _slow_motion := 1.0 # Time scale outside hit-stop, under Tuning.game_speed
var _coin_players: Array[AudioStreamPlayer] = []
var _clank_player: AudioStreamPlayer
var _bad_clank_player: AudioStreamPlayer
var _deflect_player: AudioStreamPlayer
var _coin_bad_player: AudioStreamPlayer
var _next_coin_player := 0
var _last_coin := -100000 # Ticks (ms) of the last coin sound
var _coin_chain := 0 # Coins in the current chain

func _ready() -> void:
	# Keeps checking the clock while the game is paused or slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in COIN_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = COIN_VOLUME_DB
		add_child(voice)
		_coin_players.append(voice)
	_clank_player = AudioStreamPlayer.new()
	_clank_player.stream = CLANK
	add_child(_clank_player)
	_bad_clank_player = AudioStreamPlayer.new()
	_bad_clank_player.stream = CLANK_BAD
	add_child(_bad_clank_player)
	_deflect_player = AudioStreamPlayer.new()
	_deflect_player.stream = DEFLECT
	add_child(_deflect_player)
	_coin_bad_player = AudioStreamPlayer.new()
	_coin_bad_player.stream = COIN_BAD
	_coin_bad_player.volume_db = COIN_VOLUME_DB
	add_child(_coin_bad_player)

# Ends hit-stop by the real-time clock, since timers run slow while it's on.
func _process(_delta: float) -> void:
	if _hitstop_until != 0 && Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
	if _hitstop_until == 0:
		# Set every frame so debug menu changes apply at once
		Engine.time_scale = Tuning.game_speed * _slow_motion

# Runs the game at `time_scale` of normal speed until end_time_effects. Hit-stop still
# freezes it further.
func slow_motion(time_scale: float) -> void:
	_slow_motion = time_scale
	if _hitstop_until == 0:
		Engine.time_scale = Tuning.game_speed * _slow_motion

# Back to normal speed at once: slow motion and any hit-stop end.
func end_time_effects() -> void:
	_slow_motion = 1.0
	_hitstop_until = 0
	Engine.time_scale = Tuning.game_speed

# Freezes the game for `seconds` of real time. Overlapping calls extend, never shorten.
func hitstop(seconds: float) -> void:
	if !Tuning.hitstop_enabled:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = Tuning.hitstop_time_scale * Tuning.game_speed

# Shakes the game camera with one of the SHAKE_ presets. A weaker shake never cuts a
# stronger one short.
func shake(preset: Array) -> void:
	if Game.camera != null:
		Game.camera.shake_at_least(preset[0], preset[1], preset[2] * Tuning.shake_multiplier)

# Plays a sound with its pitch nudged up or down by up to `spread`, so repeats don't sound
# identical. `base` shifts the centre pitch (used for combo pitch-ups).
func play(sound: Node, spread := 0.08, base := 1.0) -> void:
	if sound == null:
		return
	sound.pitch_scale = base * randf_range(1.0 - spread, 1.0 + spread)
	sound.play()

# An arrow reaching the player: a coin sound pitched well down, so it reads as loot but
# not money.
func arrow_sound() -> void:
	var voice := _coin_players[_next_coin_player]
	_next_coin_player = (_next_coin_player + 1) % COIN_VOICES
	voice.stream = COIN_SOUNDS.pick_random()
	play(voice, 0.04, 0.7)

# Swords meeting: a parry, or a deflected shot. `bad` is the duller, lower version for
# when the player's swing is blocked and they're the one staggered.
func clank(bad := false) -> void:
	play(_bad_clank_player if bad else _clank_player, 0.06)

# A fireball batted back, by the player's sword or a wizard.
func deflect_sound() -> void:
	play(_deflect_player, 0.06)

# Plays a coin pickup sound, pitched up the further into a quick chain of coins it is.
func coin_sound() -> void:
	var now := Time.get_ticks_msec()
	var since := now - _last_coin
	if since < COIN_GAP:
		return
	_coin_chain = _coin_chain + 1 if since < COIN_CHAIN else 0
	_last_coin = now
	var voice := _coin_players[_next_coin_player]
	_next_coin_player = (_next_coin_player + 1) % COIN_VOICES
	voice.stream = COIN_SOUNDS.pick_random()
	play(voice, 0.03, 1.0 + COIN_PITCH_STEP * mini(_coin_chain, COIN_PITCH_MAX_STEPS))

# Coins taken from the player (a troll's hit): the bad version of the pickup sound.
func coin_stolen_sound() -> void:
	play(_coin_bad_player, 0.04)

# Gives a sprite the flash shader. Call once, then flash() whenever it's hit.
func add_flash(sprite: CanvasItem) -> void:
	var material := ShaderMaterial.new()
	material.shader = FlashShader
	sprite.material = material

# Flashes a sprite (set up with add_flash) to `color` and fades back over `seconds`.
func flash(sprite: CanvasItem, seconds := 0.12, color := Color.WHITE) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash", 1.0)
	var tween := sprite.create_tween()
	# Hold full white for a moment so it reads even at low frame rates.
	tween.tween_interval(seconds * 0.4)
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("flash", v),
		1.0, 0.0, seconds * 0.6)

# Fades a sprite (set up with add_flash) to greyscale, or back with `on` false.
func set_grey(sprite: CanvasItem, on: bool, seconds := 0.08) -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return
	var current: Variant = material.get_shader_parameter("grey") # null until first set
	var from: float = current if current != null else 0.0
	sprite.create_tween().tween_method(
		func(v: float) -> void: material.set_shader_parameter("grey", v),
		from, 1.0 if on else 0.0, seconds)

# A one-shot spray of square particles that frees itself. `direction` biases the spray
# (Vector2.ZERO sprays all round).
func burst(parent: Node, at: Vector2, color: Color, amount := 10, speed := 60.0,
		direction := Vector2.ZERO, size := 2.0, lifetime := 0.4) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.color = color
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.5
	p.damping_max = speed * 2.5
	p.gravity = Vector2.ZERO
	if direction == Vector2.ZERO:
		p.spread = 180.0
	else:
		p.direction = direction
		p.spread = 45.0
	# Fade out over the lifetime.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.z_index = 5
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

# A quick star glint at `offset` from `parent`, which it follows. Enemies flash one just
# before they strike so the player can see it coming.
# `solid` colours it all over (a knight's unparryable swing); left transparent it's drawn
# as the art is.
func twinkle(parent: Node2D, offset: Vector2, solid := Color(0, 0, 0, 0)) -> void:
	var t: Node2D = Twinkle.new()
	t.solid = solid
	t.position = offset
	t.z_index = 5
	parent.add_child(t)
	# Rides on the twinkle node, which outlives the sound, so overlapping twinkles from
	# several enemies don't cut each other off. An unparryable (solid) twinkle sounds lower
	# and harsher: pitched down, with a slightly detuned second voice beating against it.
	if solid.a == 0:
		_twinkle_voice(t, 1.0, TWINKLE_VOLUME_DB)
	else:
		_twinkle_voice(t, UNPARRYABLE_TWINKLE_PITCH, TWINKLE_VOLUME_DB)
		_twinkle_voice(t, UNPARRYABLE_TWINKLE_PITCH * UNPARRYABLE_TWINKLE_DETUNE, TWINKLE_VOLUME_DB - 3.0)

func _twinkle_voice(t: Node2D, pitch: float, volume_db: float) -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = TWINKLE_SOUND
	sound.volume_db = volume_db
	t.add_child(sound)
	play(sound, 0.05, pitch)

# Stars circling at `offset` from `parent` (over its head). Stays until the caller frees it.
func dizzy(parent: Node2D, offset: Vector2) -> Node2D:
	var d: Node2D = Dizzy.new()
	d.position = offset
	d.z_index = 5
	parent.add_child(d)
	return d

# Leaves a permanent stain on the floor of `room` (blood, ash, scorch) so cleared rooms
# remember the fight.
func splat(room: Node2D, at: Vector2, color: Color, radius := 9.0) -> void:
	var s: Node2D = Splat.new()
	s.color = color
	s.radius = radius
	if room.has_method("is_floor_at"):
		s.is_floor = room.is_floor_at
	# Placed before it enters the tree, since it lays out its pieces in _ready.
	s.position = room.to_local(at)
	room.add_child(s)

# Throws `total` coins out of `at` as pickups that fly to the player and are credited when
# they arrive. Splits the value over a handful of coins.
func drop_coins(parent: Node, at: Vector2, total: int) -> void:
	if total <= 0:
		return
	@warning_ignore("integer_division")
	var count := clampi(total / 10, 1, 6)
	@warning_ignore("integer_division")
	var each := total / count
	var remainder := total - each * count
	for i in count:
		var coin: Node2D = Coin.new()
		coin.value = each + (remainder if i == 0 else 0)
		parent.add_child(coin)
		coin.global_position = at

# Throws `count` arrows out of `at` as pickups that fly to the player and are added to
# Game.arrows when they arrive.
func drop_arrows(parent: Node, at: Vector2, count: int) -> void:
	for i in count:
		var arrow: Node2D = ArrowPickup.new()
		parent.add_child(arrow)
		arrow.global_position = at
