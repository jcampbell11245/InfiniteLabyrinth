class_name Pilot
extends MeleeEnemy

# A goblin that rides dragons, centaurs and orcs (any Enemy with `mountable`). On foot it
# fights exactly as a goblin does (MeleeEnemy) until it notices the player. From then on, at
# every decision (as it notices them, after each swing, and every Tuning.pilot_decide_time
# while it waits its turn), it picks between fighting on and going for a mount:
# Tuning.pilot_mount_chance of the time it runs to the nearest mount nobody is riding (at
# Tuning.pilot_seek_speed times its speed) and climbs on; otherwise, or with no free mount, it
# fights as a goblin until the next decision. A mount can also start the room
# with a pilot already on it (Enemy.spawn_with_pilot, the room creator's Pilot switch, or
# Tuning.pilot_spawn_chance), which counts towards clearing the room like any enemy.
#
# Riding, it sits on the mount's back (Enemy.pilot_seat) and does nothing of its own until
# the mount's attack (a swing, a combo, a charge; a dragon's fireball only if the player
# parried it) is over. Then, with the player within Tuning.pilot_strike_reach, it adds one more
# hit, the last of the combo: a goblin slash, windup held Tuning.pilot_strike_hold so its glint
# comes after the player's sword cooldown. The mount waits for it before attacking again. A
# mount that had its whole combo cleared (its last hit parried, or dazed from behind) isn't
# stunned for it any more: only parrying this slash stuns it (Enemy._pilot_finishes_combo),
# and its parry bar counts the slash as a step still to clear. As with every combo, a hit of
# the mount's that caught the player ends the combo, so no slash follows it.
#
# Its body and hurtbox are off while it rides: the player's sword (and arrows, spins and
# blasts) hit the mount, and the mount's hits taken come off the pilot's health first
# (Enemy._rider_absorbs), whatever the mount's own defences let through. Only once the pilot
# is dead does the mount start to take damage. A sword meeting the mount while the pilot's
# slash winds up is timed against the pilot's glint (meets_sword): in the window it's a
# parry, which cancels the slash and stuns the mount; early, it's blocked and staggers the
# player, as for any attack.
#
# A pilot that climbs on after noticing the player makes its mount notice them too.
#
# If the mount dies with the pilot still on it (falling down a pit, say) the pilot jumps off
# and fights on foot.

var mount: Enemy = null
var _strike_pending := false # The mount's attack is over; slash once the player's in reach
var _saved_layer := 0
var _saved_mask := 0
var _wants_mount := false # Its last decision was to go for a mount (see the top of the file)
var _decide_left := 0.0 # Seconds before it decides again while waiting its turn
var _had_noticed := false # noticed, last physics frame

func _physics_process(delta: float) -> void:
	if mount != null:
		if is_instance_valid(mount) && !mount.is_queued_for_deletion():
			_ride()
			return
		dismount()
	if player.in_transition:
		return
	_update_decision(delta)
	var target := _mount_to_seek()
	if target != null && !_animation_is("slash") && !_is_reacting():
		_seek_mount(target, delta)
		_apply_knockback(delta)
		return
	super(delta)

# --- On foot ---

# Decides again (see the top of the file): as it notices the player, and every
# Tuning.pilot_decide_time after while it isn't swinging or running to a mount. Its swings
# decide too (_on_swing_finished).
func _update_decision(delta: float) -> void:
	if !noticed:
		_had_noticed = false
		_wants_mount = false
		return
	if !_had_noticed:
		_had_noticed = true
		_decide()
		return
	if _animation_is("slash") || (_wants_mount && _free_mount() != null):
		return # Swinging, or on its way to a mount (with none free it decides again)
	_decide_left -= delta
	if _decide_left <= 0:
		_decide()

func _decide() -> void:
	_wants_mount = randf() < Tuning.pilot_mount_chance
	_decide_left = Tuning.pilot_decide_time

# A swing on foot is an action: it decides again after each one.
func _on_swing_finished() -> void:
	super()
	if mount == null && noticed:
		_decide()

# The nearest mount in its room nobody is riding, if it has noticed the player and decided to
# go for one; else null.
func _mount_to_seek() -> Enemy:
	if !_wants_mount || !noticed || !room.player_active || !is_player_in_room():
		return null
	return _free_mount()

# The nearest mount in its room nobody is riding, or null.
func _free_mount() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in room.get_children():
		var other := node as Enemy
		if other == null || !other.mountable || is_instance_valid(other.rider) \
				|| other.is_queued_for_deletion() || other.health <= 0:
			continue
		var distance := other.position.distance_to(position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best

func _seek_mount(target: Enemy, delta: float) -> void:
	end_group_rush()
	var gap := target.feet_position().distance_to(feet_position())
	if gap <= _body_radius(target) + _body_radius(self) + Tuning.pilot_mount_reach:
		mount_on(target)
		return
	var before := position
	_walk_to(target.position, speed * Tuning.pilot_seek_speed, delta)
	_face_roam(position - before)

# About half the width of an enemy's feet (its body's collision shape), in pixels.
static func _body_radius(enemy: Enemy) -> float:
	var feet := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet == null || feet.shape == null:
		return 0.0
	var size := feet.shape.get_rect().size * enemy.scale.abs()
	return maxf(size.x, size.y) / 2

# --- Riding ---

# Climbs onto `target`, which it rides from now on.
func mount_on(target: Enemy) -> void:
	mount = target
	target.rider = self
	_wants_mount = false
	# A pilot that has seen the player rides its mount straight at them: the mount notices
	# them too (and alerts the room, as noticing always does).
	if noticed && is_player_in_room() && "noticed" in target:
		target.set("noticed", true)
	_saved_layer = collision_layer
	_saved_mask = collision_mask
	collision_layer = 0 # Not in the way of the player or the mount
	collision_mask = 0
	hurtbox.set_deferred("disabled", true) # Hits go to the mount, and from there to it
	knockback = Vector2.ZERO
	_strike_pending = false
	end_group_rush()
	_end_windup_hold()
	_play("idle")
	_ride()

# Gets off (its mount died, or is gone) where the mount stood, and fights on foot.
func dismount() -> void:
	if is_instance_valid(mount):
		if mount.rider == self:
			mount.rider = null
		global_position = mount.global_position
	mount = null
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	hurtbox.set_deferred("disabled", false)
	_strike_pending = false
	if is_player_in_room():
		noticed = true
	_end_windup_hold()
	_play("idle")
	_point_pivots() # Back to its own slash reach

func _ride() -> void:
	global_position = mount.seat_position()
	_moving = false # It sits; the mount does the walking (no walk cycle on its back)
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	z_index = mount.z_index + 1 # Sits on top
	if mount.is_stunned() && _animation_is("slash"): # Parried, or dazed: the slash is off
		_end_windup_hold()
		_play("idle")
	if _strike_pending:
		_strike_pending = false
		if _can_strike():
			_start_strike()
	if !_animation_is("slash"):
		if mount.direction != "":
			direction = mount.direction
		_point_pivots()

func _can_strike() -> bool:
	return !mount.is_stunned() && room.player_active && is_player_in_room() \
		&& _to_player().length() <= Tuning.pilot_strike_reach

func _start_strike() -> void:
	_start_swing(_is_player_mostly_horizontal())
	_follow_up_ready = false # One hit, no double attack
	_unparryable = false
	_next_hold = Tuning.pilot_strike_hold
	z_index = mount.z_index + 1

# The mount's attack is over (Enemy._combo_finished): one more hit, its own slash.
func follow_up_strike() -> void:
	_strike_pending = true

# Riding, free to add a slash now: not already about to or slashing, its mount on its feet
# and the player in reach. A mount that cleared its combo asks (Enemy._pilot_finishes_combo).
func can_follow_up() -> bool:
	return mount != null && !_strike_pending && !is_striking() && _can_strike()

# About to slash (the mount's attack just ended) or slashing.
func follow_up_coming() -> bool:
	return mount != null && (_strike_pending || is_striking())

# Riding and partway through its follow-up slash.
func is_striking() -> bool:
	return mount != null && _animation_is("slash")

# The player's sword met its mount while its slash winds up: timed against its glint. True
# if that settled it (a parry, or a block); false lets the hit land on the mount (and so on
# the pilot's health) as usual.
func meets_sword(from_direction: String) -> bool:
	if !is_striking() || animator.frame > attack_frame:
		return false
	match _parry_timing():
		Parry.IN_WINDOW:
			player.mark_swing_parried()
			_parry_feedback()
			_end_windup_hold()
			_play("idle")
			mount._parry_progress = 1.0 # The combo's last hit cleared
			mount.stagger(from_direction)
			return true
		Parry.EARLY:
			_block_player_swing.call_deferred(from_direction, player.swing_started_frame)
			return true
	return false

# A hit on its mount, taken by it instead (Enemy._rider_absorbs).
func absorb_hit(amount: float, critical: bool) -> void:
	if health <= 0:
		return
	if critical || Tuning.one_hit_kills:
		health = 0
	else:
		health -= amount
	Juice.flash(animator)
	Juice.burst(room, global_position, blood_color, 6, 60.0, Vector2.ZERO)
	if health <= 0.0001:
		health = 0
		die()

# Its slash reaches Tuning.pilot_strike_reach while it rides, so it lands from the mount's
# back on a player standing where the mount fights from; on foot, a goblin's own reach.
func _fit_slash_to_facing() -> void:
	if mount == null:
		super()
		return
	var rect := hitbox.shape as RectangleShape2D
	var far := Tuning.pilot_strike_reach / absf(scale.x)
	rect.size.x = far - _slash_near
	hitbox.position.x = (_slash_near + far) / 2

func die() -> void:
	if is_instance_valid(mount) && mount.rider == self:
		mount.rider = null
	mount = null
	super()

func _on_reset() -> void:
	super()
	_strike_pending = false
	_wants_mount = false
	_had_noticed = false

# The flicker after a hit taken on foot ends; riding, its hurtbox stays off.
func _on_invincibility_cooldown_timeout() -> void:
	super()
	if mount != null:
		hurtbox.disabled = true
