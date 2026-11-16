class_name Projectile
extends CharacterBody2D

# A straight-flying shot: the player's arrows, wizard fireballs and boss lasers. Set
# `direction` and `damage` after instancing it. The player reads `damage` and `direction`
# when a ProjectileHitbox touches it.
#
# A deflectable shot (fireballs) can be hit back by the player's sword, and batted back
# again by a wizard, each time getting stronger and faster (see deflect). Once the player
# has hit it back it is hostile to enemies instead of the player, and tinted to show it.

const SPAWN_MARGIN := 5.0 # Distance from walls to keep the spawn point, covering the hitbox

@export var speed: float # Pixels/sec
@export var rotates: bool # Turn the sprite to face `direction` (art faces left)
@export var rotate_hitbox: bool # Turn the hitbox with the sprite
@export var breaks_on_hit: bool # Stop and play "break" on impact instead of vanishing
@export var free_in_end_room: bool # Vanish once the player reaches the end room
@export var impact_color := Color(0.85, 0.75, 0.55) # Splinters or sparks sprayed on impact
@export var deflectable: bool # The player's sword sends it back instead of breaking it

const PLAYER_OWNED_TINT := Color(0.6, 0.85, 1.6) # Modulate once the player has hit it back

var direction := "": set = _set_direction
var damage: float
var hostile_to_player := true # False once the player has deflected it, until it comes back
var deflections := 0 # Times it has been hit back, by either side
var _hit := false # Impact effects play once, though area and body signals can both fire
var _contacts: Array[Node2D] = [] # Deflectable shots: touched this frame, resolved at its end

func _ready() -> void:
	$ExistenceTime.start(Tuning.projectile_lifetime)

func _physics_process(_delta: float) -> void:
	if free_in_end_room && Game.player.current_room == Constants.END_ROOM:
		queue_free()
	
	velocity = Direction.to_vector(direction) * speed
	move_and_slide()

func _set_direction(value: String) -> void:
	direction = value
	if !rotates:
		return
	var degrees := 0.0
	match direction:
		Direction.RIGHT: $SpritePivot/Sprite2D.flip_h = true
		Direction.UP: degrees = 90.0
		Direction.DOWN: degrees = 270.0
	$SpritePivot.rotation_degrees = degrees
	if rotate_hitbox:
		$ProjectileHitbox.rotation_degrees = degrees

# Sends the shot off `new_direction`, stronger and faster, and switches which side it
# can hurt. Called for the player's sword and for a wizard batting it back.
func deflect(new_direction: String) -> void:
	deflections += 1
	direction = new_direction
	damage *= Tuning.deflect_damage_multiplier
	speed = minf(speed * Tuning.deflect_speed_multiplier, Tuning.deflect_max_speed)
	_set_hostile_to_player(!hostile_to_player)
	$ExistenceTime.start(Tuning.projectile_lifetime)
	Juice.burst(get_parent(), global_position, Color(1, 0.95, 0.7), 8, 80.0,
		Direction.to_vector(new_direction), 1.5, 0.2)

# Enemy shots sit on the enemy projectile layer and look for the player; deflected ones
# move to the arrow layer and look for enemies, like the player's arrows. Walls (top
# tiles) stop both. Deferred, since deflecting happens inside collision callbacks.
func _set_hostile_to_player(hostile: bool) -> void:
	hostile_to_player = hostile
	var hitbox: Area2D = $ProjectileHitbox
	var layer := Constants.Layer.ENEMY_PROJECTILE if hostile else Constants.Layer.ARROW
	var target := Constants.Layer.PLAYER if hostile else Constants.Layer.ENEMY
	var mask := (1 << (target - 1)) | (1 << (Constants.Layer.TOP_TILES - 1))
	hitbox.set_deferred("collision_layer", 1 << (layer - 1))
	hitbox.set_deferred("collision_mask", mask)
	set_deferred("collision_layer", 1 << (layer - 1))
	modulate = Color.WHITE if hostile else PLAYER_OWNED_TINT

# True for the player's sword mid-swing, which deflects a shot aimed at the player.
func _is_deflecting_sword(node: Node2D) -> bool:
	if !deflectable || !hostile_to_player || node.get_name() != "Hitbox":
		return false
	var player := node.get_parent().get_parent() as Player
	return player != null && player.is_slashing()

func _on_hitbox_hit(area_or_body: Node2D) -> void:
	if _hit:
		return
	if !deflectable:
		_impact()
		return
	# The sword and the player's hurtbox can both touch it in the same frame; wait for
	# everything this frame to come in, so a deflect wins over a hit.
	if _contacts.is_empty():
		_resolve_contacts.call_deferred()
	_contacts.append(area_or_body)

func _resolve_contacts() -> void:
	var touched := _contacts.duplicate()
	_contacts.clear()
	if _hit:
		return
	for node in touched:
		if is_instance_valid(node) && _is_deflecting_sword(node):
			var player: Player = node.get_parent().get_parent()
			deflect(player.direction)
			Juice.deflect_sound()
			Juice.hitstop(0.05)
			return
	_impact()

func _impact() -> void:
	if !_hit:
		_hit = true
		Juice.burst(get_parent(), global_position, impact_color, 6, 60.0,
			-Direction.to_vector(direction), 1.5, 0.25)
	if breaks_on_hit:
		speed = 0
		$AnimatedSprite2D.play("break")
	else:
		queue_free()

func _on_existence_time_timeout() -> void:
	queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "break":
		queue_free()
