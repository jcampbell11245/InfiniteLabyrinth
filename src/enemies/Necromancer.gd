class_name Necromancer
extends Caster

# Necromancer, of the wizard family: keeps its distance (see Caster) and every
# Tuning.necromancer_raise_cooldown_min/max seconds, while anyone killed in its room is
# there to raise (Room.fallen), swings its staff and brings one of them, picked at random,
# back to life where it fell (see Room.raise_fallen). Necromancers aren't raised, by each
# other or anyone. The rising itself is a placeholder: a burst and a fade-in.

const RAISE_SOUND := preload("res://assets/sfx/laser_unlock.wav")
const RAISE_PITCH := 0.45
const RAISE_COLOR := Color(0.6, 0.45, 0.9)
const RISE_TIME := 0.4 # Seconds the raised enemy takes to fade in

var _raise_sound: AudioStreamPlayer

func _ready() -> void:
	super()
	_raise_sound = AudioStreamPlayer.new()
	_raise_sound.stream = RAISE_SOUND
	_raise_sound.volume_db = -4.0
	add_child(_raise_sound)

# Builds the room's pathfinding grid (used to find open floor) from the physics step, where
# it has to be made, before the first raise needs it.
func _physics_process(delta: float) -> void:
	room.nav()
	super(delta)

func _cooldown_range() -> Vector2:
	return Vector2(Tuning.necromancer_raise_cooldown_min, Tuning.necromancer_raise_cooldown_max)

func _can_cast() -> bool:
	return !room.fallen.is_empty()

func _cast() -> void:
	if room.fallen.is_empty():
		return
	var raised := room.raise_fallen(randi() % room.fallen.size())
	if raised == null:
		return
	Juice.play(_raise_sound, 0.05, RAISE_PITCH)
	_staff_sparks(RAISE_COLOR)
	Juice.burst(room, raised.global_position, RAISE_COLOR, 16, 60.0, Vector2.ZERO, 2.0, 0.5)
	var sprite: CanvasItem = raised.animator
	sprite.modulate.a = 0.0
	sprite.create_tween().tween_property(sprite, "modulate:a", 1.0, RISE_TIME)
