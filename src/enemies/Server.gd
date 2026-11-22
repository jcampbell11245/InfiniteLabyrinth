class_name Server
extends Enemy

# A standing server tower that boosts the other enemies round it (see ServerBuff): attack,
# defense or speed. It never moves or attacks and isn't knocked back; it breaks after
# Tuning.server_hits sword hits (sooner to charged arrows). It doesn't count towards
# clearing its room, so it can be left standing, or broken after the fight.
#
# It covers either a circle `radius` pixels round it, drawn as a pixelated ring, or its
# whole room (`whole_room`), with a faint tint of its boost's colour over that area (see
# ServerArea). Its `buff` is a kind ("attack", "defense", "speed"), "random" (one kind from
# `buff_pool`, picked as the room is built) or "random_swap" (switching between the kinds
# in `buff_pool` every Tuning.server_swap_time, under a fixed pink tint).
#
# As each floor is built some servers turn silver, into premium servers
# (ServerBuff.roll_floor_servers): a premium server also gives Tuning.floor_server_strength of
# its boost to every enemy anywhere on the floor while it stands, and its room shows silver on
# the minimap from the start.

const GROUP := "servers"
const FLOOR_GROUP := "floor_servers"
const SILVER_FRAMES := preload("res://src/enemies/ServerSilverFrames.tres")
const BreakSound := preload("res://assets/sfx/server_break.wav")
const BREAK_VOLUME_DB := -4.0
const SPARK := Color(0.55, 0.9, 1.0) # Electric sparks off a hit
const SILVER_SPARK := Color(0.92, 0.95, 1.0)
const BEACON := Vector2(0, -24) # The light in the socket on its cap, which shows the boost's colour
const BEACON_SIZE := 2.0
const BEACON_BLINK := 0.6 # Seconds per blink

## One of ServerBuff.SETTINGS.
@export_enum("attack", "defense", "speed", "random", "random_swap") var buff := "random"
## The kinds "random" and "random_swap" pick from; all three if left empty.
@export var buff_pool: PackedStringArray = ["attack", "defense", "speed"]
## Covers its whole room instead of a circle.
@export var whole_room := false
## Pixels from its origin that it covers, when not whole_room.
@export var radius := 120.0

var floor_server := false # Turned silver (a premium server) as the floor was built (make_floor_server)
var kind: ServerBuff.Kind = ServerBuff.Kind.ATTACK # The boost it gives now
var _area: ServerArea
var _swap_timer: Timer
var _blink := 0.0
var _beacon: Node2D # Drawn over the sprite (a parent's own drawing goes under its children)
var _full_health := 0.0 # Health when undamaged, from the tuning
var _swing_landed := -2 # Player.swing_started_frame of the last swing that hit it
var _spin_landed := -2 # Player.spin_started_frame of the last spin that hit it

@onready var hit_sound: AudioStreamPlayer = $Hit

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	kind = _pick_kind()
	if buff == ServerBuff.RANDOM_SWAP:
		_swap_timer = _add_timer(_swap)
		_swap_timer.one_shot = false
		_swap_timer.start(Tuning.server_swap_time)
	_area = ServerArea.new()
	_area.server = self
	room.add_child.call_deferred(_area) # The room is still adding its children
	_beacon = Node2D.new()
	_beacon.draw.connect(_draw_beacon)
	add_child(_beacon)
	_play("idle", Direction.DOWN)

func _exit_tree() -> void:
	if is_instance_valid(_area):
		_area.queue_free()

func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, BEACON_BLINK * 2)
	_beacon.queue_redraw()

# Health is a number of sword hits at the default damage (Tuning.server_hits), so anything
# that changes the player's damage changes how many it takes, as on any enemy. A change to
# the tuning keeps the share of health it has left.
func apply_tuning() -> void:
	var share := health / _full_health if _full_health > 0 else 1.0
	super.apply_tuning()
	_full_health = Tuning.server_hits * Tuning.enemy_health_multiplier
	health = _full_health * share

func _on_tuning_changed(key: String) -> void:
	super._on_tuning_changed(key) # Rereads server_hits too
	if key == "server_swap_time" && _swap_timer != null:
		_swap_timer.start(Tuning.server_swap_time)

func counts_towards_clearing() -> bool:
	return false

# Strength of boost `of_kind` on `enemy` from this server (see ServerBuff.strengths_on).
func strength_on(enemy: Enemy, of_kind: ServerBuff.Kind) -> float:
	if of_kind != kind || health <= 0:
		return 0.0
	if enemy.room == room && covers(enemy.global_position):
		return 1.0
	return Tuning.floor_server_strength if floor_server else 0.0

# True if `point` (global) is in its area.
func covers(point: Vector2) -> bool:
	if whole_room:
		return true
	return point.distance_to(global_position) <= radius

# The colour its area is tinted: its boost's, or pink while it keeps swapping.
func area_color() -> Color:
	return ServerBuff.SWAP_COLOR if buff == ServerBuff.RANDOM_SWAP else ServerBuff.COLORS[kind]

# Turns it silver, a premium server: its boost reaches the whole floor (see strength_on).
func make_floor_server() -> void:
	floor_server = true
	add_to_group(FLOOR_GROUP)
	animator.sprite_frames = SILVER_FRAMES
	_play("idle", Direction.DOWN)

func _pick_kind() -> ServerBuff.Kind:
	if buff != ServerBuff.RANDOM && buff != ServerBuff.RANDOM_SWAP:
		var named := ServerBuff.kind_named(buff)
		return named as ServerBuff.Kind if named >= 0 else ServerBuff.Kind.ATTACK
	var pool := _pool()
	return pool[randi() % pool.size()]

# The kinds in buff_pool (all of them if it names none).
func _pool() -> Array[ServerBuff.Kind]:
	var pool: Array[ServerBuff.Kind] = []
	for name in buff_pool:
		var named := ServerBuff.kind_named(name)
		if named >= 0 && !pool.has(named):
			pool.append(named as ServerBuff.Kind)
	if pool.is_empty():
		pool = ServerBuff.KINDS.duplicate()
	return pool

# A random swap server moves on to another kind from its pool.
func _swap() -> void:
	var others := _pool()
	others.erase(kind)
	if !others.is_empty():
		kind = others[randi() % others.size()]

# --- Being hit ---

# One sword swing, or one spin, takes one hit. Its invincibility after a hit is shorter than
# either, so the blade, still out, would hit it again as it wore off; this remembers which
# swing and spin (by the physics frame each started on) last landed and ignores them after.
# A server never attacks, so there's no parry or guard to work out: every swing just lands.
func _on_player_sword(from_direction: String) -> void:
	if player.swing_started_frame != _swing_landed && _hit_once(from_direction, player.sword_damage()):
		_swing_landed = player.swing_started_frame

func spin_hit() -> void:
	if player.spin_started_frame != _spin_landed && _hit_once(_away_from_player(), player.spin_damage()):
		_spin_landed = player.spin_started_frame

# Takes a hit of `amount`; true if it landed (it wasn't still invincible from the last one).
func _hit_once(from_direction: String, amount: float) -> bool:
	var before := health
	take_damage(from_direction, amount)
	return health < before

# It stands its ground: no knockback, and a spin or parry never stuns it.
func stagger(_from_direction: String, _stun_time := -1.0) -> void:
	pass

func _after_hit() -> void:
	knockback = Vector2.ZERO
	Juice.burst(room, global_position + Vector2(0, -8), SILVER_SPARK if floor_server else SPARK,
		8, 90.0, Vector2.ZERO, 1.5, 0.25)
	Juice.play(hit_sound, 0.1)

func die() -> void:
	if health > 0:
		health = 0
	Juice.burst(room, global_position + Vector2(0, -8), SILVER_SPARK if floor_server else SPARK,
		22, 120.0, Vector2.ZERO, 2.5, 0.5)
	_play_break_sound()
	super.die()

# The break sound plays from the room, since the server is freed as it dies.
func _play_break_sound() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = BreakSound
	sound.bus = &"SFX"
	sound.volume_db = BREAK_VOLUME_DB
	room.add_child(sound)
	sound.finished.connect(sound.queue_free)
	Juice.play(sound, 0.06)

# --- Drawing ---

# The beacon on top, blinking in its boost's colour (or pink for a random swap server).
func _draw_beacon() -> void:
	if _blink > BEACON_BLINK:
		return
	var at := BEACON / scale
	var size := Vector2.ONE * BEACON_SIZE / scale
	_beacon.draw_rect(Rect2(at - size / 2, size), area_color())
