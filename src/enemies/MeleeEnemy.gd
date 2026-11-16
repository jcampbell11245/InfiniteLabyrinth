extends Enemy

# Goblin and Knight: walks at the player once they enter its detection zone, or once the
# player hits it from anywhere (an arrow from across the room), then slashes when close. A knight (only_hit_during_attack) blocks any hit that lands outside its slash
# and is stunned for a second afterwards.
#
# Enemies whose sprites have them also react to hits: "block" plays once when a hit is
# shrugged off, and "vuln" flashes while invincible after a hit lands. The enemy stands
# still until the reaction is over.


@export var only_hit_during_attack: bool
@export var starting_direction := Direction.RIGHT

# Hit by the player while they're in this room: it chases and attacks even outside its
# detection zone, until the player leaves the room.
var noticed := false

@onready var hitbox: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var detection_zone: Area2D = $DetectionZonePivot/DetectionZone

func _ready() -> void:
	super()
	direction = starting_direction
	_play("idle")

func _process(_delta: float) -> void:
	if !player.in_transition:
		_update_windup()
		if !_animation_is("slash"):
			hitbox.disabled = true
		if !_is_reacting():
			animate()
	else:
		_play("idle")

func _physics_process(delta: float) -> void:
	if player.in_transition:
		return
	if !is_player_in_room():
		noticed = false

	# Turns to track the player while alerted. The two branches gate the room check
	# differently, which is kept from the original.
	var alerted := is_detected() || invincibility_cooldown.time_left != 0
	var blocking: bool = only_hit_during_attack && $Block.playing
	if _is_player_mostly_horizontal() && (alerted || blocking) && is_player_in_room():
		_face_player_horizontally()
	elif alerted || (blocking && is_player_in_room()):
		_face_player_vertically()
	
	if !_animation_is("slash"):
		$HitboxPivot.rotation_degrees = Direction.to_rotation_degrees(direction)
		$DetectionZonePivot.rotation_degrees = Direction.to_rotation_degrees(direction)
	
	if _is_reacting():
		pass
	elif _is_player_far() && !_animation_is("slash") && is_detected():
		move_and_collide(_to_player().normalized() * speed * delta)
	elif attack_cooldown.time_left == 0 && is_detected():
		if !only_hit_during_attack || $BlockStun.time_left == 0:
			animate()
			attack()
	
	_apply_knockback(delta)

func animate() -> void:
	if _animation_is("slash") && animator.frame == attack_end_frame:
		_play("idle")
	
	if _is_player_far() && !_animation_is("slash") && is_detected():
		_play("walk")
	elif !_animation_is("slash") && attack_cooldown.time_left == 0 && is_detected():
		_play("slash")
	elif !_animation_is("slash"):
		_play("idle")

func attack() -> void:
	if animator.visible:
		attack_cooldown.start(attack_cooldown_length)

# True when the player is in this room, not down a pitfall, and either inside the detection
# zone or has hit this enemy. The room check stops enemies next door chasing or slashing
# through the shared wall.
func is_detected() -> bool:
	return room.player_active && is_player_in_room() \
		&& (noticed || detection_zone.get_overlapping_bodies().has(player))

func _on_reset() -> void:
	noticed = false
	hitbox.disabled = true
	var block_stun: Timer = get_node_or_null("BlockStun")
	if block_stun != null:
		block_stun.stop()

# Any hit, even one a knight blocks, gives the player away.
func take_damage(from_direction: String, amount: float) -> void:
	if is_player_in_room():
		noticed = true
	super(from_direction, amount)

func _blocks_hit() -> bool:
	if only_hit_during_attack && !_animation_is("slash"):
		$BlockStun.start(Tuning.knight_block_stun)
		Juice.play($Block)
		_play_reaction("block")
		return true
	return false

func _after_hit() -> void:
	_play_reaction("vuln")

# Plays a hit reaction if this enemy's sprites have one. It uses the enemy's own facing,
# not the hit's direction that take_damage shows when it interrupts a slash, so the enemy
# keeps looking at the player.
func _play_reaction(action: String) -> void:
	if animator.sprite_frames.has_animation(action + "_" + direction):
		_play(action)

func _on_staggered() -> void:
	_play_reaction("vuln")

# True while stunned from a parry, while a block plays out, or while flashing after a hit.
func _is_reacting() -> bool:
	if is_stunned():
		return true
	if _animation_is("block"):
		return animator.is_playing()
	if _animation_is("vuln"):
		return invincibility_cooldown.time_left != 0
	return false

func _lose_health(amount: float, critical: bool) -> void:
	if critical:
		Juice.play($Crit, 0.05)
	super(amount, critical)

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("slash") && animator.frame == attack_frame:
		Juice.play($Attack)
		hitbox.disabled = false
