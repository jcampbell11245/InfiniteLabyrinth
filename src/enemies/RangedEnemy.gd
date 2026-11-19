extends Enemy

# Wizard: backs away while the player is lined up with it on either axis, otherwise casts
# one fireball at a time, launched straight at the player and homing on them (see
# Projectile.launch_at). It can't turn on a dime, so a hard enough dodge gets out of its
# way, and it still breaks on stalagmites and walls. A fireball the player hits back homes
# on the wizard and is batted back again (homing on the player) just before it lands, unless the wizard fumbles it
# (Tuning.wizard_deflect_miss_chance each time), or the rally has got too fast for the
# player's sword cooldown to answer (see _player_could_return). The two can rally a fireball back and
# forth, stronger and faster each time. Wizards sharing a room take turns casting (see
# _is_my_turn), so only one fireball is ever coming at the player.
#
# Up close (Tuning.wizard_melee_range) it stops casting and swipes with its staff instead:
# a weak melee attack (Tuning.wizard_melee_damage) that uses the same clash system as the
# goblin and knight (see Enemy._on_player_sword): a windup hold, a twinkle, then the strike.
# Parried in the window it's stunned; a swing before the twinkle is blocked and staggers the
# player. The swipe borrows the cast animation, copied in as "slash_<dir>", until it has
# art of its own. Casting itself still sits out parrying: a sword hit mid-cast just lands.

const Fireball := preload("res://src/projectiles/Fireball.tscn")
const SWIPE_SOUND := preload("res://assets/sfx/slash1.wav")
# Fireball cooldown (replaces attack_cooldown_length once a fireball is out), melee range,
# cooldown and damage, and the deflect miss chance are in Tuning.
const DEFLECT_REACH := 22.0 # Pixels ahead of the wizard where it bats a fireball back
const DEFLECT_WIDTH := 12.0 # Pixels either side of a fireball's path that still count
const PLAYER_SWORD_REACH := 20.0 # Pixels from the player out to where their sword meets a fireball
# The staff swipe's hitbox, in the wizard's own (unscaled) units, reaching out to the right
# before its pivot turns it to face.
const SWIPE_HITBOX_SIZE := Vector2(40, 48)
const SWIPE_HITBOX_CENTRE := Vector2(22, -4)
const SWIPE_ANIMATION_SPEED := 9.0 # Frames/sec; a touch slower than casting so it reads
const SWIPE_PITCH := 1.3
const LAST_CASTER_META := &"last_wizard_caster" # Room meta: the wizard that cast last there

# Room-local bounds on backing away. The wizard faces the player and backs away from them,
# so facing left it backs towards RETREAT_LIMIT_RIGHT, and so on.
const RETREAT_LIMIT_LEFT := 232
const RETREAT_LIMIT_RIGHT := 424
const RETREAT_LIMIT_UP := 214
const RETREAT_LIMIT_DOWN := 406

var retreat_blocked := false # Backing away ran into something; shoot instead until the next cast
var _judged: Dictionary = {} # Fireball -> its deflections when last swung at, so each return gets one try
# Its fireball still in the room (flying, rallying or breaking). It won't cast another until
# this one is gone.
var _fireball: Projectile
var _hitbox_pivot: Marker2D
var _hitbox: CollisionShape2D
var _swipe_sound: AudioStreamPlayer
# Between staff swipes. Apart from attack_cooldown, which a fireball sets for much longer,
# so a wizard that has just cast can still swipe at a player who closes in.
var _swipe_cooldown: Timer

func _ready() -> void:
	super()
	_add_swipe_animations()
	_add_swipe_hitbox()
	_swipe_sound = AudioStreamPlayer.new()
	_swipe_sound.stream = SWIPE_SOUND
	add_child(_swipe_sound)
	_swipe_cooldown = _add_timer()

func _process(_delta: float) -> void:
	if player.in_transition:
		if direction != "":
			_play("idle")
		return
	_update_windup()
	_swipe_cooldown.paused = attack_cooldown.paused # Both wait out a windup hold
	if !_animation_is("slash"):
		_hitbox.disabled = true
	if !is_stunned():
		animate()
	elif direction != "":
		_play("idle")

func _physics_process(delta: float) -> void:
	if player.in_transition || !room.player_active || !is_player_in_room():
		return
	if is_stunned(): # Parried
		_apply_knockback(delta)
		return

	_try_deflect()
	if _animation_is("slash"):
		pass # Rooted and committed to its facing until the swipe is over
	elif _in_melee_range():
		_melee()
	else:
		if !_animation_is("shoot"):
			_face_player()
		if _is_retreating():
			var motion := -_to_player().normalized() * speed * delta
			if !_safe_step(motion): # Won't back onto a trap
				motion = Vector2.ZERO
			motion = ground_motion(motion, delta)
			var collision := move_and_collide(motion)
			# Grazing something still counts as moving; only a near-stop means it's stuck.
			# Going nowhere at all (a trap ahead, or held at the edge of paste) is stuck too,
			# so it shoots instead of backing away on the spot for ever.
			retreat_blocked = motion == Vector2.ZERO \
				|| (collision != null && collision.get_travel().length() < motion.length() / 2)
		elif _can_cast():
			animate()
			attack()

	_apply_knockback(delta)

func animate() -> void:
	if !is_player_in_room():
		return
	if (_animation_is("shoot") || _animation_is("slash")) && animator.frame == attack_end_frame:
		_play("idle")

	if direction == "" || _animation_is("slash"):
		return
	if _in_melee_range():
		if !_animation_is("shoot"):
			_play("idle")
	elif _is_retreating():
		_play("walk")
	elif !_animation_is("shoot") && _can_cast():
		_play("shoot")
	elif !_animation_is("shoot"):
		_play("idle")

func attack() -> void:
	retreat_blocked = false
	if animator.visible && is_player_in_room():
		attack_cooldown.start(attack_cooldown_length / ground_factor()) # Quicker on a speed tile

func shoot_fireball() -> void:
	if !is_player_in_room():
		return
	Juice.play($Attack)
	var fireball: Projectile = Fireball.instantiate()
	_fireball = fireball
	room.set_meta(LAST_CASTER_META, self)
	room.add_child(fireball)
	fireball.position = room.clamp_to_floor(position, Projectile.SPAWN_MARGIN)
	fireball.direction = direction
	fireball.damage = damage
	fireball.speed = Tuning.fireball_speed
	fireball.shooter = self # Hit back, it homes on this wizard
	fireball.launch_at(player)
	attack_cooldown.start(Tuning.wizard_burst_cooldown)

# Off cooldown, with no fireball of its own still out, and its turn (see _is_my_turn).
func _can_cast() -> bool:
	return attack_cooldown.time_left == 0 && !is_instance_valid(_fireball) && _is_my_turn()

# Wizards sharing a room take turns: only one fireball (cast, flying or rallying) is out at
# a time, and the wizard that cast last waits for another to go, unless none of the others
# can cast just now (stunned, or close enough to the player to be using the staff).
func _is_my_turn() -> bool:
	var someone_else_ready := false
	for other in _other_wizards():
		if is_instance_valid(other._fireball) || other._is_winding_up_cast():
			return false
		if !other.is_stunned() && !other._in_melee_range():
			someone_else_ready = true
	var last: Variant = room.get_meta(LAST_CASTER_META, null)
	return !(someone_else_ready && is_instance_valid(last) && last == self)

# Mid-cast, before the fireball is out.
func _is_winding_up_cast() -> bool:
	return _animation_is("shoot") && animator.frame < attack_frame

# The other living wizards in this room.
func _other_wizards() -> Array:
	var out := []
	for node in room.get_children():
		if node != self && node.get_script() == get_script() && !node.is_queued_for_deletion():
			out.append(node)
	return out

# The animation whose windup can be parried: the staff swipe. Casting can't be.
func _attack_action() -> String:
	return "slash"

func _on_reset() -> void:
	retreat_blocked = false
	_judged.clear()
	_swipe_cooldown.stop()
	_hitbox.disabled = true

# --- Staff swipe (see the top of the file) ---

func _in_melee_range() -> bool:
	return _to_player().length() <= Tuning.wizard_melee_range

# Up close: a cast not yet out is dropped, and it turns to the player and swipes when it can.
func _melee() -> void:
	if _animation_is("shoot") && animator.frame < attack_frame:
		_play("idle")
	if _animation_is("shoot"):
		return # Already loosed; let the cast finish
	_face_player()
	if _swipe_cooldown.is_stopped() && !AttackCoordinator.for_room(room).other_is_swinging(self):
		_start_swipe()

func _start_swipe() -> void:
	_point_hitbox()
	_restart_attack(-1.0) # Fresh windup with a random hold
	_swipe_cooldown.start(Tuning.wizard_melee_cooldown)
	# No casting straight after a swipe either, though a longer fireball cooldown stands.
	attack_cooldown.start(maxf(attack_cooldown.time_left, Tuning.wizard_melee_cooldown))

# Partway through a swipe, up to the frame it strikes on. Other enemies hold off their
# own windups while one is under way (AttackCoordinator.other_is_swinging).
func is_swinging() -> bool:
	return _animation_is("slash") && animator.frame <= attack_frame

func melee_damage() -> float:
	return Tuning.wizard_melee_damage * Tuning.enemy_damage_multiplier

func _face_player() -> void:
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically(0)

func _point_hitbox() -> void:
	_hitbox_pivot.rotation_degrees = Direction.to_rotation_degrees(direction)

# "slash_<dir>" for each facing, copied from the cast animation, so the shared windup and
# parry code (which looks for "slash") has something to hold and time. The SpriteFrames is
# shared by every wizard, so only the first adds them.
func _add_swipe_animations() -> void:
	var frames := animator.sprite_frames
	for dir: String in [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]:
		var swipe := "slash_" + dir
		if frames.has_animation(swipe):
			continue
		var cast := "shoot_" + dir
		frames.add_animation(swipe)
		frames.set_animation_loop(swipe, false)
		frames.set_animation_speed(swipe, SWIPE_ANIMATION_SPEED)
		for i in frames.get_frame_count(cast):
			frames.add_frame(swipe, frames.get_frame_texture(cast, i), frames.get_frame_duration(cast, i))

# HitboxPivot/Hitbox, named and layered like a goblin's, so the player takes it as a melee
# hit (see Player._on_hurtbox_area_shape_entered).
func _add_swipe_hitbox() -> void:
	_hitbox_pivot = Marker2D.new()
	_hitbox_pivot.name = "HitboxPivot"
	add_child(_hitbox_pivot)
	var area := Area2D.new()
	area.name = "Hitbox"
	area.collision_layer = 1 << (Constants.Layer.ENEMY - 1)
	area.collision_mask = 1 << (Constants.Layer.PLAYER - 1)
	area.monitorable = true
	_hitbox_pivot.add_child(area)
	_hitbox = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SWIPE_HITBOX_SIZE
	_hitbox.shape = rect
	_hitbox.position = SWIPE_HITBOX_CENTRE
	_hitbox.disabled = true
	area.add_child(_hitbox)

# --- Fireballs ---

# Swings at any player-deflected fireball about to hit, once per return.
func _try_deflect() -> void:
	for node in room.get_children():
		var shot := node as Projectile
		if shot == null || !shot.deflectable || shot.hostile_to_player || shot._hit:
			continue
		if _judged.get(shot, -1) == shot.deflections || !_is_incoming(shot):
			continue
		_judged[shot] = shot.deflections
		if randf() < Tuning.wizard_deflect_miss_chance:
			continue # Fumbled; it flies on and hits
		if !_player_could_return(shot):
			continue # No point; it takes the hit rather than send back an unanswerable one
		_face(Direction.to_vector(shot.direction) * -1)
		shot.deflect(direction)
		Juice.flash(animator, 0.1, Color(0.8, 0.6, 1.0))
		Juice.deflect_sound()
	# Forget fireballs that have gone.
	for shot in _judged.keys():
		if !is_instance_valid(shot):
			_judged.erase(shot)

# Batted back now, `shot` would reach the player's sword no sooner than they can swing
# again plus Tuning.wizard_volley_reaction_time. Once a rally is so fast that the sword
# cooldown makes it unanswerable, the wizard lets the fireball hit it instead.
func _player_could_return(shot: Projectile) -> bool:
	var return_speed := minf(shot.speed * Tuning.deflect_speed_multiplier, Tuning.deflect_max_speed)
	if return_speed <= 0:
		return true
	var distance := maxf(global_position.distance_to(player.global_position) - PLAYER_SWORD_REACH, 0.0)
	var travel := distance / return_speed
	return travel >= player.seconds_until_can_swing() + Tuning.wizard_volley_reaction_time

# Heading straight at the wizard and about to arrive. Measured along its real path, since a
# homing fireball comes in on a diagonal.
func _is_incoming(shot: Projectile) -> bool:
	var heading := shot.velocity.normalized() if shot.velocity != Vector2.ZERO \
		else Direction.to_vector(shot.direction)
	var to_me := global_position - shot.global_position
	var ahead := to_me.dot(heading)
	return ahead > 0 && ahead < DEFLECT_REACH && absf(to_me.cross(heading)) < DEFLECT_WIDTH

# Turns to face along `facing`, one of the four direction vectors.
func _face(facing: Vector2) -> void:
	for dir in [Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN]:
		if Direction.to_vector(dir).is_equal_approx(facing):
			direction = dir

# Within CLOSE_RANGE of the player on at least one axis.
func _is_player_lined_up() -> bool:
	var offset := _to_player()
	return abs(offset.x) < CLOSE_RANGE || abs(offset.y) < CLOSE_RANGE

# Backs away while the player is lined up, until it reaches a wall or bumps into something.
# Pinned, it stands and shoots instead, then tries backing away again after the cast.
func _is_retreating() -> bool:
	return _is_player_lined_up() && _can_retreat() && !retreat_blocked && !_animation_is("shoot") && attack_cooldown.time_left == 0

func _can_retreat() -> bool:
	match direction:
		Direction.LEFT: return position.x < RETREAT_LIMIT_RIGHT
		Direction.RIGHT: return position.x > RETREAT_LIMIT_LEFT
		Direction.UP: return position.y < RETREAT_LIMIT_DOWN
		Direction.DOWN: return position.y > RETREAT_LIMIT_UP
	return false

func _on_animated_sprite_2d_frame_changed() -> void:
	if _animation_is("shoot") && animator.frame == attack_frame:
		shoot_fireball()
	elif _animation_is("slash") && animator.frame == attack_frame:
		Juice.play(_swipe_sound, 0.08, SWIPE_PITCH)
		_hitbox.disabled = false
