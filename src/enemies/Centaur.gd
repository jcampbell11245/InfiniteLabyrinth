class_name Centaur
extends MeleeEnemy

# Cyber centaurs: the Centaur, the bull-bodied Bucentaur and the Taurtaur (two horse bottoms
# joined by one neck, the top one upside down). They walk, notice the player, take turns,
# guard and join group rushes exactly as goblins do (MeleeEnemy); what's theirs is how they
# attack.
#
# Each attack is a combo, a run of hits picked from `combos`. Every hit gets its own windup
# and spark, so the spark always says what's coming:
# - a clash (Hit.CLASH): the front half's weapon (a taurtaur's front hooves, stomping), with
#   a white spark at the weapon. It has to be parried; anything else (taking it, rolling away
#   from it) ends the combo.
# - a kick (Hit.KICK): it turns its back and lashes out with its hind legs, with a red spark
#   at the hooves. It can't be parried (Enemy._on_player_sword), so the player rolls through
#   or out of reach; one that misses carries the combo on, one that lands ends it.
# Clearing a hit goes straight on to the next, its windup held Tuning.centaur_combo_hold so
# the player's sword cooldown has run out by the next spark. Only clearing the whole combo
# stuns it: parrying a last clash staggers it as any parry does, dodging a last kick stuns it
# the same way (_combo_cleared). A parry partway through never does. Each hit hurts for its
# own Tuning damage (melee_damage).
#
# Instead of a combo it may charge (`charge`, Tuning.centaur_charge_chance of attacks): it
# holds still for Tuning.centaur_charge_hold_min/max, sparks as it sets off, gallops straight
# at the player at Tuning.centaur_charge_speed and strikes the moment it arrives, like a
# dragon's charge. A Bucentaur's charge (Charge.CLASH) sparks white: any swing begun after
# the spark that meets it before the strike parries it, and slamming into a wall or rock
# dazes it. A Taurtaur's lunge (Charge.ROLL) sparks red and can't be parried; it ploughs on
# and stands frozen for Tuning.heavy_end_lag afterwards, like a knight's red swing.
#
# In a group rush it makes a single clash, so a rush stays one parry per enemy.
#
# Kicks and charges play "slash_kick" and "slash_charge" animations. Their names start with
# "slash", so all the shared attack code (windups, parries, hitbox, turning) treats them as
# the attack; _play picks which one the hit under way shows.

enum Hit { CLASH, KICK, CHARGE }
enum Charge { NONE, CLASH, ROLL }

const COMBO_FLASH := Color(0.6, 0.9, 1.0) # Shown as a cleared hit flows into the next

# Its combos, each a run of Hit values. One is picked at random for each attack.
@export var combos: Array[PackedInt32Array] = []
@export var charge := Charge.NONE
# Spark points, as weapon_tips (which places a clash's spark), for its kicks and charges.
@export var kick_tips := {}
@export var charge_tips := {}

var _combo := PackedInt32Array() # The attack under way; empty when not attacking
var _combo_index := 0 # Hit of _combo under way
var _hit_landed := false # The hit under way has hurt the player
var _rush_pending := false # Starting a group-rush strike: a single clash
var _dashing := false # A charge under way has set off
var _dash_left := 0.0 # Pixels of the charge still to run
var _charge_dir := Vector2.RIGHT

func _process(delta: float) -> void:
	super(delta)
	if !_animation_is("slash"): # Finished, interrupted or parried
		_dashing = false
		_combo = PackedInt32Array()

func _physics_process(delta: float) -> void:
	super(delta)
	if _dashing:
		_charge_step(delta)

# --- Combos ---

func _start_swing(horizontal: bool) -> void:
	_combo = _pick_attack()
	_combo_index = 0
	super(horizontal)
	_set_up_hit()

func rush_strike() -> void:
	_rush_pending = true
	super()
	_rush_pending = false

func _pick_attack() -> PackedInt32Array:
	if _rush_pending || combos.is_empty():
		return PackedInt32Array([Hit.CLASH])
	if charge != Charge.NONE && randf() < Tuning.centaur_charge_chance:
		return PackedInt32Array([Hit.CHARGE])
	return combos.pick_random()

func _hit() -> int:
	return _combo[_combo_index] if _combo_index < _combo.size() else Hit.CLASH

func _set_up_hit() -> void:
	var hit := _hit()
	_unparryable = hit == Hit.KICK || (hit == Hit.CHARGE && charge == Charge.ROLL)
	_follow_up_ready = false
	_hit_landed = false
	_dashing = false
	# Only a lunge freezes in end lag after; a kick flows on into the rest of the combo.
	_end_lagged = hit != Hit.CHARGE
	if hit == Hit.CHARGE:
		_next_hold = randf_range(Tuning.centaur_charge_hold_min,
			maxf(Tuning.centaur_charge_hold_min, Tuning.centaur_charge_hold_max))

func _has_next_hit() -> bool:
	return _combo_index < _combo.size() - 1

# Starts the combo's next hit at once, its windup held so its spark comes after the
# player's sword cooldown.
func _next_hit() -> void:
	_combo_index += 1
	_set_up_hit()
	Juice.flash(animator, 0.12, COMBO_FLASH)
	_restart_attack(Tuning.centaur_combo_hold)
	attack()

# A clash in the combo parried: on to the next hit rather than staggering, unless it was
# the last.
func _parried_follow_up() -> bool:
	if !_has_next_hit():
		return false
	_next_hit()
	return true

# A hit has played out without being parried (a parried one never gets here).
func _on_swing_finished() -> void:
	var hit := _hit()
	if hit == Hit.KICK && !_hit_landed:
		if _has_next_hit():
			_next_hit()
			return
		_combo_cleared()
	_combo = PackedInt32Array()
	super()

# The player hit by this enemy's hitbox (Player reads this after damage that counted).
func landed_hit() -> void:
	_hit_landed = true

# Every hit of the combo cleared, the last one a dodged kick: stunned as if parried, knocked
# back away from the player.
func _combo_cleared() -> void:
	_parry_feedback()
	stagger(_direction_of(-_to_player()))

# Whichever of the four directions `v` is nearest.
static func _direction_of(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return Direction.LEFT if v.x < 0 else Direction.RIGHT
	return Direction.UP if v.y < 0 else Direction.DOWN

# Clashes, kicks and charges each hurt for their own amount, scaled like everything else by
# Tuning.enemy_damage_multiplier.
func melee_damage() -> float:
	var amount := Tuning.centaur_clash_damage
	match _hit():
		Hit.KICK:
			amount = Tuning.centaur_kick_damage
		Hit.CHARGE:
			amount = Tuning.centaur_charge_damage
	return amount * Tuning.enemy_damage_multiplier

# The hit under way picks which attack animation "slash" shows.
func _play(action: String, dir := direction) -> void:
	if action == "slash" && !_combo.is_empty():
		match _hit():
			Hit.KICK:
				action = "slash_kick"
			Hit.CHARGE:
				action = "slash_charge"
	super(action, dir)

func _twinkle_position() -> Vector2:
	if !_combo.is_empty():
		match _hit():
			Hit.KICK:
				if kick_tips.has(direction):
					return kick_tips[direction]
			Hit.CHARGE:
				if charge_tips.has(direction):
					return charge_tips[direction]
	return super()

func _on_staggered() -> void:
	super()
	_dashing = false
	_combo = PackedInt32Array()

func _on_reset() -> void:
	super()
	_dashing = false
	_combo = PackedInt32Array()

# --- Charges ---

func _charging() -> bool:
	return !_combo.is_empty() && _hit() == Hit.CHARGE && _animation_is("slash")

# The windup hold ends by setting off, sparking as it goes, rather than opening the usual
# parry window: the strike waits until it reaches the player.
func _twinkle() -> void:
	if _charging() && !_dashing:
		_set_off()
		_twinkled_at = Time.get_ticks_msec()
		Juice.twinkle(self, _twinkle_position(),
			UNPARRYABLE_TWINKLE_COLOR if _unparryable else Color(0, 0, 0, 0))
	else:
		super()

# Re-aims at the player (so the hold isn't a free head start to dodge), turning its pose to
# match, and gallops off.
func _set_off() -> void:
	var to_player := _to_player()
	_charge_dir = to_player.normalized() if to_player != Vector2.ZERO else Direction.to_vector(direction)
	if _is_player_mostly_horizontal():
		_face_player_horizontally()
	else:
		_face_player_vertically()
	_point_pivots()
	var frame := animator.frame
	_turning = true
	_play("slash")
	animator.frame = frame
	_turning = false
	animator.pause()
	_dashing = true
	_dash_left = minf(to_player.length() + Tuning.centaur_charge_overshoot, Tuning.centaur_charge_max_distance)

func _charge_step(delta: float) -> void:
	var step := minf(Tuning.centaur_charge_speed * delta, _dash_left)
	var collision := move_and_collide(_charge_dir * step)
	_dash_left -= step
	var before_clamp := position.x
	_keep_off_side_walls()
	var hit_wall := !is_equal_approx(position.x, before_clamp) \
		|| (collision != null && !(collision.get_collider() is Enemy))
	if hit_wall && !_unparryable:
		_slam_into_wall()
		return
	# Reached the player (or the end of the run, dodged, or blocked by another enemy): it
	# strikes at once, going straight to the strike frame.
	var ahead := _to_player().dot(_charge_dir) - _engage_distance(absf(_charge_dir.x) >= absf(_charge_dir.y))
	if ahead <= 0 || _dash_left <= 0 || collision != null:
		_dashing = false
		_end_windup_hold()
		animator.frame = attack_frame

# Galloped into a wall or rock: dazed just as if parried.
func _slam_into_wall() -> void:
	_dashing = false
	Juice.burst(room, global_position + _charge_dir * 12.0, Color(0.75, 0.68, 0.55), 14, 70.0,
		-_charge_dir, 2.0, 0.4)
	Juice.clank()
	Juice.hitstop(PARRY_HITSTOP)
	Juice.shake(Juice.SHAKE_MEDIUM)
	stagger(_direction_of(-_charge_dir))

# A charge strikes as it arrives, maybe before a parry window would have closed, and the
# sword only meets it then: any swing begun after the spark that connects up to the strike
# parries it.
func _parry_timing() -> Parry:
	var timing := super()
	if timing == Parry.LATE && _charging():
		return Parry.IN_WINDOW
	return timing

# Committed to its line: a charge doesn't turn to follow a player who steps round it.
func _turn_mid_attack() -> void:
	if !_charging():
		super()
