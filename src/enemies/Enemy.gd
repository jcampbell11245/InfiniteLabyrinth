class_name Enemy
extends CharacterBody2D

# Shared code for everything the player can fight. Subclasses decide how to move and
# attack; this handles facing, knockback, taking hits and dying.
#
# An enemy lives directly under its Room and only acts while the player is in that room.
# Animations are named "<action>_<direction>", e.g. "slash_left".

signal died(enemy: Enemy)

const KNOCKBACK_FRICTION := 200 # Pixels/sec lost per second
const CRIT_ROLL_MAX := 30 # A hit crits when randi_range(0, CRIT_ROLL_MAX) < damage upgrade level
const CLOSE_RANGE := 25 # Pixels on either axis

@export var speed: float
@export var knockback_speed: float
@export var damage: float # Read by the player when this enemy's Hitbox touches it
@export var health: float
@export var attack_frame: int # Attack animation frame the hit or shot happens on
@export var attack_end_frame: int # Attack animation frame that returns to idle
@export var attack_cooldown_length: float
@export var invincibility_time := 0.3 # Seconds after a hit before the next one counts
@export var coin_reward := 0 # Coins per floor number

var direction := "" # Direction facing; "" until first set
var knockback := Vector2.ZERO
var critical_chance := 0

@onready var player: Player = Game.player
@onready var room: Room = get_parent()
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var hurtbox: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var invincibility_cooldown: Timer = $InvincibilityCooldown

func _ready() -> void:
	critical_chance = SaveData.damage_level

func take_damage(from_direction: String) -> void:
	if invincibility_cooldown.time_left != 0:
		return
	knockback = Direction.to_vector(from_direction) * knockback_speed
	if _blocks_hit():
		return
	
	# Interrupts an attack. Faces the direction the hit travels in, not the attacker.
	if _animation_is("slash"):
		_play("idle", from_direction)
	
	hurtbox.disabled = true
	invincibility_cooldown.start(invincibility_time)
	animator.modulate.a = 0.5
	
	_lose_health(_roll_critical())
	if health <= 0:
		die()
	_after_hit()

func die() -> void:
	Game.add_coins(roundi(coin_reward * _coin_multiplier()))
	died.emit(self)
	queue_free()

func is_player_in_room() -> bool:
	return player.current_room == room.room_id

# --- Overridable hooks ---

# True when a hit should be shrugged off (knockback still applies).
func _blocks_hit() -> bool:
	return false

func _roll_critical() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(0, CRIT_ROLL_MAX) < critical_chance

func _lose_health(critical: bool) -> void:
	if critical:
		health = 0
	else:
		health -= 1

func _after_hit() -> void:
	pass

# Coins are coin_reward times "floor.looting": floor 1 with no looting is x1.0, floor 1 with
# looting 1 is x1.1, floor 2 with looting 3 is x2.3. Looting tops out at 9, one decimal digit.
func _coin_multiplier() -> float:
	return Game.overworld.floor_number + SaveData.looting_level / 10.0

# --- Helpers for subclasses ---

func _to_player() -> Vector2:
	return player.global_position - global_position

func _is_player_far() -> bool:
	var offset := _to_player()
	return abs(offset.x) > CLOSE_RANGE || abs(offset.y) > CLOSE_RANGE

func _is_player_mostly_horizontal() -> bool:
	var offset := _to_player()
	return abs(offset.x) > abs(offset.y)

func _face_player_horizontally() -> void:
	direction = Direction.LEFT if _to_player().x < 0 else Direction.RIGHT

# Facing up draws the enemy in front of the player, facing down behind.
func _face_player_vertically(z_facing_down := 1) -> void:
	if _to_player().y < 0:
		direction = Direction.UP
		z_index = 10
	else:
		direction = Direction.DOWN
		z_index = z_facing_down

func _animation_is(action: String) -> bool:
	return String(animator.animation).begins_with(action)

func _play(action: String, dir := direction) -> void:
	animator.play(action + "_" + dir)

# Slides off any knockback from the last hit.
func _apply_knockback(delta: float) -> void:
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	velocity = knockback
	move_and_slide()
	knockback = velocity

func _on_invincibility_cooldown_timeout() -> void:
	animator.modulate.a = 1
	hurtbox.disabled = false

func _on_hurtbox_area_shape_entered(_area_id: RID, area: Area2D, _area_shape: int, _self_shape: int) -> void:
	if area.get_name() == "Hitbox":
		take_damage(area.get_parent().get_parent().direction)
	elif area.get_name() == "ArrowHitbox":
		take_damage(area.get_parent().direction)
