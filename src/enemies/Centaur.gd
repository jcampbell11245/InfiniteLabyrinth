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
#   or out of reach. Either way the combo carries on, but only a kick that misses counts as
#   cleared.
# Each hit goes straight on to the next, its windup held Tuning.centaur_combo_hold so the
# player's sword cooldown has run out by the next spark. Only clearing every hit of the
# combo stuns it: parrying a last clash staggers it as any parry does, dodging a last kick
# stuns it the same way (_combo_cleared). A parry partway through never does, and a combo
# with a kick that caught the player ends without a stun. Each hit hurts for its own Tuning
# damage (melee_damage).
#
# Instead of a combo it may charge (`charge`, Tuning.centaur_charge_chance of attacks): it
# holds still for Tuning.centaur_charge_hold_min/max, sparks as it sets off, gallops straight
# at the player at Tuning.centaur_charge_speed and strikes the moment it arrives, like a
# dragon's charge. A Bucentaur's charge (Charge.CLASH) sparks white: any swing begun after
# the spark that meets it before the strike parries it, and slamming into a wall or rock
# dazes it. A Taurtaur's lunge (Charge.ROLL) sparks red and can't be parried; it ploughs on
# and stands frozen for Tuning.heavy_end_lag afterwards, like a knight's red swing. Either
# way a clash follows (CHARGE_COMBO), and only parrying that too stuns it.
#
# A sword hit from behind mid-combo (after rolling through a kick, say) doesn't hurt: it
# clanks like a parry and clears the hit it's on, once that hit has sparked
# (_on_player_sword). The parry bar steps up with every cleared hit, however it was cleared,
# and is full when it's stunned.
#
# A player who gets out of reach mid-combo breaks it off (_break_off): no stun, and it starts
# over, walking back up for a fresh combo or, if it can charge,
# Tuning.centaur_chase_charge_chance of the time charging straight away.
#
# In a group rush it makes a single clash, so a rush stays one parry per enemy.
#
# Its hurtbox follows the drawn body frame by frame (sprite_bounds), so a hit lands wherever
# the sprite is: the rider, a taurtaur's top horse, legs thrown out in a kick.
#
# Kicks and charges play "slash_kick" and "slash_charge" animations. Their names start with
# "slash", so all the shared attack code (windups, parries, hitbox, turning) treats them as
# the attack; _play picks which one the hit under way shows.

enum Hit { CLASH, KICK, CHARGE }
enum Charge { NONE, CLASH, ROLL }

const COMBO_FLASH := Color(0.6, 0.9, 1.0) # Shown as a cleared hit flows into the next
# A charge is followed by a clash: clearing the charge isn't enough to stun it, the swing
# after has to be parried too.
const CHARGE_COMBO := [Hit.CHARGE, Hit.CLASH]

# Its combos, each a run of Hit values. One is picked at random for each attack.
@export var combos: Array[PackedInt32Array] = []
@export var charge := Charge.NONE
# Spark points, as weapon_tips (which places a clash's spark), for its kicks and charges.
@export var kick_tips := {}
@export var charge_tips := {}
# Each attack animation's drawn body, frame by frame (Rect2s in its own units, ground shadow
# left out), measured from the sprite sheets: the hurtbox follows it (_fit_hurtbox).
@export var sprite_bounds := {}

var _combo := PackedInt32Array() # The attack under way; empty when not attacking
var _combo_index := 0 # Hit of _combo under way
var _hit_landed := false # The hit under way has hurt the player
var _cleared := 0 # Hits of the combo the player has cleared (parried, dodged or hit from behind)
var _rush_pending := false # Starting a group-rush strike: a single clash
var _dashing := false # A charge under way has set off
var _dash_left := 0.0 # Pixels of the charge still to run
var _charge_dir := Vector2.RIGHT
var _next_attack := PackedInt32Array() # Set to make the next attack this, not a random pick
var _skip_charge := false # The next attack is a combo, not a charge
var _hurt_rect: RectangleShape2D # Its own copy of the hurtbox shape, resized every frame
var _fitted := "" # Animation and frame the hurtbox was last fitted to

func _ready() -> void:
	super()
	_hurt_rect = (hurtbox.shape as RectangleShape2D).duplicate() as RectangleShape2D
	hurtbox.shape = _hurt_rect
	_fit_hurtbox()

func _process(delta: float) -> void:
	super(delta)
	if !_animation_is("slash"): # Finished, interrupted or parried
		_dashing = false
		_combo = PackedInt32Array()
	else:
		_show_combo_progress()
	_fit_hurtbox()

# The parry bar shows the combo's cleared hits, a step each, full when it's stunned.
func _show_combo_progress() -> void:
	if !_combo.is_empty() && _animation_is("slash"):
		_parry_progress = float(_cleared) / _combo.size()

# The hurtbox covers whatever the sprite draws this frame (sprite_bounds): the rider, a
# taurtaur's top horse, legs thrown out in a kick. Where that isn't measured it keeps the
# scene's box.
func _fit_hurtbox() -> void:
	var key := "%s %d" % [animator.animation, animator.frame]
	if key == _fitted:
		return
	_fitted = key
	var frames: Array = sprite_bounds.get(String(animator.animation), [])
	if animator.frame >= frames.size():
		return
	var bounds: Rect2 = frames[animator.frame]
	_hurt_rect.size = bounds.size
	hurtbox.position = bounds.get_center()

func _physics_process(delta: float) -> void:
	super(delta)
	if _dashing:
		_charge_step(delta)

# --- Combos ---

func _start_swing(horizontal: bool) -> void:
	_combo = _pick_attack()
	_combo_index = 0
	_cleared = 0
	super(horizontal)
	_set_up_hit()

func rush_strike() -> void:
	_rush_pending = true
	super()
	_rush_pending = false

func _pick_attack() -> PackedInt32Array:
	if _rush_pending || combos.is_empty():
		return PackedInt32Array([Hit.CLASH])
	if !_next_attack.is_empty():
		var forced := _next_attack
		_next_attack = PackedInt32Array()
		return forced
	var skip_charge := _skip_charge
	_skip_charge = false
	if charge != Charge.NONE && !skip_charge && randf() < Tuning.centaur_charge_chance:
		return PackedInt32Array(CHARGE_COMBO)
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
# player's sword cooldown. With the player out of reach it breaks off instead.
func _next_hit() -> void:
	if _out_of_reach():
		_break_off()
		return
	_combo_index += 1
	_set_up_hit()
	Juice.flash(animator, 0.12, COMBO_FLASH)
	_restart_attack(Tuning.centaur_combo_hold)
	attack()
	# Deferred: a parry sets its own bar value (Enemy._on_player_sword) after this returns.
	_show_combo_progress.call_deferred()

# A clash in the combo parried: on to the next hit rather than staggering, unless it was
# the last.
func _parried_follow_up() -> bool:
	_cleared += 1
	if _has_next_hit():
		_next_hit()
		return true
	if _all_cleared():
		return false # Enemy staggers it
	_end_combo() # A kick caught the player earlier: no stun
	return true

# A hit has played out without being parried (a parried one never gets here).
func _on_swing_finished() -> void:
	var hit := _hit()
	# A kick (or a taurtaur's red lunge) carries the combo on whether it caught the player
	# or not; only a dodged one counts as cleared (walking out of reach of the last one
	# doesn't).
	if hit == Hit.KICK || (hit == Hit.CHARGE && _unparryable):
		if !_hit_landed && (_has_next_hit() || !_out_of_reach()):
			_cleared += 1
		if _has_next_hit():
			_next_hit()
			return
		if _all_cleared():
			_combo_cleared()
	_combo = PackedInt32Array()
	super()

# Every hit of the combo was cleared: only then does finishing it stun.
func _all_cleared() -> bool:
	return _cleared >= _combo.size()

# Ends the combo without a stun (its last hit cleared, but not all of them were).
func _end_combo() -> void:
	_combo = PackedInt32Array()
	_swings_left -= 1
	_end_windup_hold()
	_play("idle")
	# Deferred: a parry sets its own bar value (Enemy._on_player_sword) after this returns.
	_reset_parry_progress.call_deferred()

# Further off than it could swing from, even closing in (MeleeEnemy._player_in_threat_range).
func _out_of_reach() -> bool:
	return !_player_in_threat_range()

# The player got out of reach mid-combo: the combo is dropped (no stun) and it starts over.
# A centaur that can charge does, Tuning.centaur_chase_charge_chance of the time; otherwise it
# walks back up (MeleeEnemy's usual approach) and opens with a fresh combo.
func _break_off() -> void:
	_combo = PackedInt32Array()
	_swings_left -= 1
	_end_windup_hold()
	_play("idle")
	if charge != Charge.NONE && randf() < Tuning.centaur_chase_charge_chance:
		_next_attack = PackedInt32Array(CHARGE_COMBO)
		_start_swing(_is_player_mostly_horizontal())
	else:
		_skip_charge = true

# The player hit by this enemy's hitbox (Player reads this after damage that counted).
func landed_hit() -> void:
	_hit_landed = true

# Every hit of the combo cleared, the last one a dodged kick or a back hit: stunned as if
# parried, knocked back away from the player.
func _combo_cleared() -> void:
	_parry_feedback()
	_parry_progress = 1.0
	stagger(_direction_of(-_to_player()))

# The sword from behind (travelling the way it faces: the player rolled through a kick or a
# charge). Mid-combo it doesn't hurt: it clanks, like a parry, and clears the hit it's on, so
# the combo goes on (or, on the last hit, it's stunned). Only once that hit has sparked,
# though, or rolling behind and swinging away would clear every hit in its windup; before
# that it's a dull clank and nothing more. Outside a combo it's an ordinary hit.
func _on_player_sword(from_direction: String) -> void:
	if _combo.is_empty() || !_animation_is("slash") || from_direction != direction:
		super(from_direction)
		return
	if _twinkled_at < 0:
		Juice.clank(true)
		return
	player.mark_swing_parried()
	_cleared += 1
	if _has_next_hit():
		_parry_feedback()
		_next_hit()
	elif _all_cleared():
		_combo_cleared()
	else:
		_parry_feedback()
		_end_combo()

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

# Turning to keep a player who steps round it in front only happens in a hit's windup, before
# its spark. After the spark it's committed, as a charge is to its line: a player who rolls
# through on the spark gets clear (though, not having parried, they end the combo without a
# stun). Swinging round after them read, on a body this big, as being hit from far off.
func _turn_mid_attack() -> void:
	if !_charging() && _twinkled_at < 0 && animator.frame < attack_frame:
		super()

# Only the strike frame itself hurts, not the follow-through after it (a goblin's blade
# stays live to catch a player rolling through; a centaur's doesn't).
func _on_animated_sprite_2d_frame_changed() -> void:
	super()
	if _animation_is("slash") && animator.frame > attack_frame:
		hitbox.disabled = true
