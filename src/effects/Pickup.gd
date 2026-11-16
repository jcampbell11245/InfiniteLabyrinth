extends Sprite2D

# Base for loot thrown out of a dying enemy (coins, arrows). It pops outward, hangs for a
# moment, then homes in on the player and is credited when it arrives. Runs while paused
# so loot in flight when the player dies still gets banked before the floor resets.
# Subclasses set the look in _ready and fill in _credit, _animate and _feedback.

const POP_SPEED := 70.0 # Pixels/sec outward at the start
const POP_TIME := 0.3 # Seconds before it starts homing
# Homing acceleration and collect distance are Tuning.pickup_home_accel/_collect_distance.

var _velocity := Vector2.ZERO
var _age := 0.0
var _credited := false

func _ready() -> void:
	z_index = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velocity = Vector2.from_angle(randf() * TAU) * POP_SPEED * randf_range(0.6, 1.0)

func _process(delta: float) -> void:
	_age += delta
	_animate(delta)
	var player := Game.player
	if player == null:
		_collect()
		return
	if _age < POP_TIME:
		_velocity = _velocity.move_toward(Vector2.ZERO, POP_SPEED * 2.5 * delta)
	else:
		var to_player := player.global_position - global_position
		if to_player.length() < Tuning.pickup_collect_distance:
			_collect()
			return
		_velocity += to_player.normalized() * Tuning.pickup_home_accel * delta
		# Turn hard towards the player so it doesn't orbit.
		_velocity = _velocity.normalized().slerp(to_player.normalized(), 0.25) * _velocity.length()
	global_position += _velocity * delta

func _collect() -> void:
	if !_credited:
		_credited = true
		_credit()
		_feedback()
	queue_free()

# Never lose loot: if it's removed before it arrives (scene change), bank it.
func _exit_tree() -> void:
	if !_credited:
		_credited = true
		_credit()

# --- Overridable hooks ---

# Adds this pickup to the player's stash.
func _credit() -> void:
	pass

# Called every frame before moving.
func _animate(_delta: float) -> void:
	pass

# Sound and the like when it reaches the player (not when banked on a scene change).
func _feedback() -> void:
	pass
