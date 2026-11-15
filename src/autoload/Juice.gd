extends Node

# Game-feel helpers shared by the player, enemies and world: hit-stop, screen shake,
# pitch-varied sounds, sprite flashes and throwaway particle bursts. None of it needs
# sprites or sounds of its own; particles are plain coloured squares.

const FlashShader := preload("res://src/effects/flash.gdshader")
const Coin := preload("res://src/effects/CoinPickup.gd")
const Splat := preload("res://src/effects/Splat.gd")

# Hit-stop slows the whole game to this fraction of normal speed rather than 0, so
# anything dividing by delta keeps working.
const HITSTOP_TIME_SCALE := 0.05

# Shake presets: [duration, frequency, amplitude]. Amplitude is in pixels before the
# display scale-up, so 1-3 is already plenty.
const SHAKE_LIGHT := [0.12, 30.0, 1.0]
const SHAKE_MEDIUM := [0.2, 30.0, 2.0]
const SHAKE_HEAVY := [0.3, 30.0, 3.0]

var _hitstop_until := 0 # Ticks (ms) when the current hit-stop ends; 0 when none

func _ready() -> void:
	# Keeps checking the clock while the game is paused or slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS

# Ends hit-stop by the real-time clock, since timers run slow while it's on.
func _process(_delta: float) -> void:
	if _hitstop_until != 0 && Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0

# Freezes the game for `seconds` of real time. Overlapping calls extend, never shorten.
func hitstop(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	if until <= _hitstop_until:
		return
	_hitstop_until = until
	Engine.time_scale = HITSTOP_TIME_SCALE

# Shakes the game camera with one of the SHAKE_ presets. A weaker shake never cuts a
# stronger one short.
func shake(preset: Array) -> void:
	if Game.camera != null:
		Game.camera.shake_at_least(preset[0], preset[1], preset[2])

# Plays a sound with its pitch nudged up or down by up to `spread`, so repeats don't sound
# identical. `base` shifts the centre pitch (used for combo pitch-ups).
func play(sound: Node, spread := 0.08, base := 1.0) -> void:
	if sound == null:
		return
	sound.pitch_scale = base * randf_range(1.0 - spread, 1.0 + spread)
	sound.play()

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

# Leaves a permanent stain on the floor of `room` (blood, ash, scorch) so cleared rooms
# remember the fight.
func splat(room: Node2D, at: Vector2, color: Color, radius := 9.0) -> void:
	var s: Node2D = Splat.new()
	s.color = color
	s.radius = radius
	room.add_child(s)
	s.global_position = at

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
