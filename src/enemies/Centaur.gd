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
#   or out of reach. Dodged, the combo carries on, but a kick only counts as cleared when
#   the player hits its back (see below). Any hit that catches the player ends the combo
#   (Enemy.landed_hit; Tuning.combos_end_on_hit).
# Each hit goes straight on to the next, its windup held Tuning.centaur_combo_hold so the
# player's sword cooldown has run out by the next spark. It takes a hit from the player for
# every hit of the combo to stun it, a parry for each clash and a hit on its back for each
# kick: parrying a last clash staggers it as any parry does, hitting the back of a last kick
# stuns it the same way (_combo_cleared). A parry partway through never does, and a combo
# with a hit the player didn't clear ends without a stun. Each hit hurts for its own Tuning
# damage (melee_damage).
#
# Instead of a combo it may charge (`charge`, Tuning.centaur_charge_chance of attacks, and
# from as far off as Tuning.centaur_charge_range, see _try_charge_from_afar): it
# holds still for Tuning.centaur_charge_hold_min/max, sparks as it sets off, gallops straight
# at the player at Tuning.centaur_charge_speed and strikes the moment it arrives, like a
# dragon's charge. A Bucentaur's charge (Charge.CLASH) sparks white: any swing begun after
# the spark that meets it before the strike parries it, and slamming into a wall or rock
# dazes it. A Taurtaur's lunge (Charge.ROLL) sparks red and can't be parried; it ploughs on
# and stands frozen for Tuning.heavy_end_lag afterwards, like a knight's red swing. Either
# way another hit follows (charge_follow_up: the Bucentaur's a clash, the Taurtaur's one of
# its kicks, turned to face the player), and only clearing that too stuns it.
#
# A sword hit from behind mid-combo (after rolling through a kick, say) doesn't hurt: it
# clanks like a parry and clears the hit it's on, once that hit has sparked
# (_on_player_sword). The parry bar is its combo bar: full as a combo starts, a step down for
# every hit cleared, however it was cleared, and empty when it's stunned.
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
# A taurtaur (alternate_halves) never turns round in a kick combo. Its two halves face
# opposite ways, so it kicks with whichever half's hind legs are on the side it's attacking:
# its bottom half first (that half faces away from the player), then its top half on the far
# side, and so on, swapping with every kick (_next_hit): each kick goes where a player rolling
# through the last one lands, and the side it came from becomes its back. After the combo it
# faces as usual.
#
# Kicks and charges play "slash_kick" and "slash_charge" animations. Their names start with
# "slash", so all the shared attack code (windups, parries, hitbox, turning) treats them as
# the attack; _play picks which one the hit under way shows.

enum Hit { CLASH, KICK, CHARGE }
enum Charge { NONE, CLASH, ROLL }

const COMBO_FLASH := Color(0.6, 0.9, 1.0) # Shown as a cleared hit flows into the next
const TOP_KICK_FRAME := Vector2i(64, 56) # Frame size in top_kick_sheet

# Its combos, each a run of Hit values. One is picked at random for each attack.
@export var combos: Array[PackedInt32Array] = []
@export var charge := Charge.NONE
# The hit after a charge (see _charge_combo): clearing the charge isn't enough to stun it.
@export var charge_follow_up := Hit.CLASH
# Spark points, as weapon_tips (which places a clash's spark), for its kicks and charges.
@export var kick_tips := {}
@export var charge_tips := {}
# Each attack animation's drawn body, frame by frame (Rect2s in its own units, ground shadow
# left out), measured from the sprite sheets: the hurtbox follows it (_fit_hurtbox).
@export var sprite_bounds := {}
# Taurtaur: its two halves face opposite ways, and it kicks with whichever half's hind legs
# are on the side it's attacking, without turning round (see _kick_is_top).
@export var alternate_halves := false
@export var top_kick_tips := {} # Spark points for the top half's kick, by the bottom half's facing
# Sheets for the top half's kick ("slash_kick_top"), a %s for the facing, added to its
# animations as it loads.
@export var top_kick_sheet := ""

var _combo := PackedInt32Array() # The attack under way; empty when not attacking
var _combo_index := 0 # Hit of _combo under way
var _cleared := 0 # Hits of the combo the player has cleared (parried or hit from behind)
var _hit_landed := false # The hit under way has hurt the player: the combo ends with it
var _rush_pending := false # Starting a group-rush strike: a single clash
var _dashing := false # A charge under way has set off
var _dash_left := 0.0 # Pixels of the charge still to run
var _charge_dir := Vector2.RIGHT
var _next_attack := PackedInt32Array() # Set to make the next attack this, not a random pick
var _skip_charge := false # The next attack is a combo, not a charge
var _far_charge_roll := -1 # 1 if it charges at this approach from afar, 0 if not, -1 unrolled
var _hurt_rect: RectangleShape2D # Its own copy of the hurtbox shape, resized every frame
var _fitted := "" # Animation and frame the hurtbox was last fitted to
# Taurtaur, mid-combo: the way its bottom half faces, fixed for the combo; "" otherwise.
var _body_facing := ""

func _ready() -> void:
	super()
	_add_top_kick_animations()
	_hurt_rect = (hurtbox.shape as RectangleShape2D).duplicate() as RectangleShape2D
	hurtbox.shape = _hurt_rect
	_fit_hurtbox()

func _process(delta: float) -> void:
	super(delta)
	if !_animation_is("slash"): # Finished, interrupted or parried
		_dashing = false
		_combo = PackedInt32Array()
		_body_facing = "" # Back to facing the player as usual
	else:
		_show_combo_progress()
	_fit_hurtbox()

# The parry bar is its combo bar: the hits still to clear, full as a combo starts (so it's
# there from the first hit, whichever kind) and a step down for each one cleared, empty once
# it's stunned.
func _show_combo_progress() -> void:
	if !_combo.is_empty() && _animation_is("slash"):
		_parry_progress = 1.0 - float(_cleared) / _combo.size()

# The hurtbox covers whatever the sprite draws this frame (sprite_bounds): the rider, a
# taurtaur's top horse, legs thrown out in a kick. It never shrinks below the standing frame
# for the way it shows (so an attack pose that pulls the body in isn't easier to miss), and
# it's padded by Tuning.centaur_hurtbox_margin all round so a swing that touches the edge of
# the sprite counts. Where that isn't measured it keeps the scene's box.
func _fit_hurtbox() -> void:
	var anim := String(animator.animation)
	var key := "%s %d %s" % [anim, animator.frame, Tuning.centaur_hurtbox_margin]
	if key == _fitted:
		return
	_fitted = key
	var frames: Array = sprite_bounds.get(anim, [])
	if animator.frame >= frames.size():
		return
	var bounds: Rect2 = frames[animator.frame]
	var standing: Array = sprite_bounds.get("idle_" + anim.get_slice("_", anim.get_slice_count("_") - 1), [])
	if !standing.is_empty():
		bounds = bounds.merge(standing[0])
	bounds = bounds.grow(Tuning.centaur_hurtbox_margin)
	_hurt_rect.size = bounds.size
	hurtbox.position = bounds.get_center()

func _physics_process(delta: float) -> void:
	_try_charge_from_afar()
	super(delta)
	if _dashing:
		_charge_step(delta)

# A centaur that can charge doesn't have to walk all the way up: with its turn to attack and
# the player out of reach but within Tuning.centaur_charge_range, it opens with a charge
# Tuning.centaur_charge_chance of the time. Rolled once each time the player comes into that
# range, so it isn't nearly certain just for their lingering there.
func _try_charge_from_afar() -> void:
	if charge == Charge.NONE || player.in_transition || !is_detected() || _animation_is("slash") \
			|| _is_reacting():
		return
	var coordinator := AttackCoordinator.for_room(room)
	var distance := _to_player().length()
	if distance > Tuning.centaur_charge_range || !_out_of_reach():
		_far_charge_roll = -1 # A fresh roll for the next approach
		return
	if !coordinator.is_attacker(self) || !_can_start_swing(coordinator):
		return
	if _far_charge_roll < 0:
		_far_charge_roll = 1 if randf() < Tuning.centaur_charge_chance else 0
	if _far_charge_roll == 1:
		_far_charge_roll = 0
		_next_attack = _charge_combo()
		_start_swing(_is_player_mostly_horizontal())

# --- Combos ---

func _start_swing(horizontal: bool) -> void:
	_combo = _pick_attack()
	_combo_index = 0
	_cleared = 0
	super(horizontal)
	if alternate_halves:
		# Its bottom half's hind legs open on the player, so its bottom half faces away.
		_body_facing = _direction_of(-Direction.to_vector(direction))
		_play("slash")
		animator.frame = 0
	_set_up_hit()

func rush_strike() -> void:
	_rush_pending = true
	super()
	_rush_pending = false

func _pick_attack() -> PackedInt32Array:
	# Its group-rush strike is one clash; nothing else is (a counter while a rush plays out
	# elsewhere in the room is an ordinary combo).
	if _rush_pending || combos.is_empty():
		return PackedInt32Array([Hit.CLASH])
	if !_next_attack.is_empty():
		var forced := _next_attack
		_next_attack = PackedInt32Array()
		return forced
	var skip_charge := _skip_charge
	_skip_charge = false
	if charge != Charge.NONE && !skip_charge && randf() < Tuning.centaur_charge_chance:
		return _charge_combo()
	return combos.pick_random()

func _hit() -> int:
	return _combo[_combo_index] if _combo_index < _combo.size() else Hit.CLASH

func _set_up_hit() -> void:
	var hit := _hit()
	_hit_landed = false
	# A lunge hit from behind in its end lag goes straight on to the next hit; the end lag
	# mustn't run on into it, or its timing out would play this hit's animation on early.
	_end_lag.stop()
	_unparryable = hit == Hit.KICK || (hit == Hit.CHARGE && charge == Charge.ROLL)
	_follow_up_ready = false
	_dashing = false
	# Only a lunge freezes in end lag after; a kick flows on into the rest of the combo.
	_end_lagged = hit != Hit.CHARGE
	if hit == Hit.CHARGE:
		_next_hold = randf_range(Tuning.centaur_charge_hold_min,
			maxf(Tuning.centaur_charge_hold_min, Tuning.centaur_charge_hold_max))

# A charge and the hit after it.
func _charge_combo() -> PackedInt32Array:
	return PackedInt32Array([Hit.CHARGE, charge_follow_up])

func _has_next_hit() -> bool:
	return _combo_index < _combo.size() - 1

# Starts the combo's next hit at once, its windup held so its spark comes after the
# player's sword cooldown. With the player out of reach it breaks off instead.
func _next_hit() -> void:
	if _out_of_reach():
		_break_off()
		return
	if alternate_halves && _hit() == Hit.CHARGE && _combo[_combo_index + 1] == Hit.KICK:
		# A taurtaur's kick after its lunge turns to the player (the lunge usually carries it
		# past them), its bottom half's hind legs kicking first as at a combo's start.
		if _is_player_mostly_horizontal():
			_face_player_horizontally()
		else:
			_face_player_vertically()
		_point_pivots()
		_body_facing = _direction_of(-Direction.to_vector(direction))
	elif _body_facing != "" && _hit() == Hit.KICK && _combo[_combo_index + 1] == Hit.KICK:
		# A taurtaur's next kick comes from its other half, on the far side, where a player
		# rolling through the last one lands; the side it came from becomes its back.
		direction = _direction_of(-Direction.to_vector(direction))
		_point_pivots()
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
	# A kick (or a taurtaur's red lunge) the player dodged carries the combo on, though it
	# isn't cleared: only a hit on its back does that (_on_player_sword), so a combo whose last
	# hit plays out like this ends without a stun. One that caught the player ends the combo.
	if (hit == Hit.KICK || (hit == Hit.CHARGE && _unparryable)) && _has_next_hit() && !_hit_landed:
		_next_hit()
		return
	_combo = PackedInt32Array()
	super()

# Its hit caught the player (Enemy.landed_hit, with Tuning.combos_end_on_hit): the combo
# stops with this hit.
func _end_combo_on_hit() -> void:
	super()
	_hit_landed = true

# Every hit of the combo was cleared: only then does finishing it stun.
func _all_cleared() -> bool:
	return _cleared >= _combo.size()

# Ends the combo without a stun (its last hit cleared, but not all of them were).
func _end_combo() -> void:
	_combo = PackedInt32Array()
	_swings_left -= 1
	_combo_finished()
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
		_next_attack = _charge_combo()
		_start_swing(_is_player_mostly_horizontal())
	else:
		_skip_charge = true

# Every hit of the combo cleared, the last one a dodged kick or a back hit: stunned as if
# parried, knocked back away from the player.
func _combo_cleared() -> void:
	_parry_feedback()
	if !_pilot_finishes_combo(): # A pilot riding it adds its slash as the last hit first
		stagger(_direction_of(-_to_player()))

# The sword from behind (travelling the way it faces: the player rolled through a kick or a
# charge). Mid-combo it doesn't hurt: it clanks, like a parry, and clears the hit it's on, so
# the combo goes on (or, on the last hit, it's stunned). Only once that hit has sparked,
# though, or rolling behind and swinging away would clear every hit in its windup; before
# that it's a dull clank and nothing more. Outside a combo it's an ordinary hit, and so it is
# on a hit that can't be cleared any more (_clearable_from_behind).
#
# A swing at the front of a kick before its spark is a dull clank too, rather than the
# stagger a swing at a red attack's front usually gets: right after a hit on a taurtaur's
# back its next kick turns that side into its front, and a player swinging again there
# hasn't done anything wrong yet. After the spark the usual rule holds.
# Whether a hit from behind can still clear the hit under way. Never once it has caught the
# player: that ends the combo with no stun, and getting round behind it afterwards doesn't
# undo that. Nor a white hit (a clash, a bucentaur's charge) once it has struck: it had to be
# parried. A red one the player rolled through (a kick, a taurtaur's lunge) can be, through
# its follow-through and end lag, since that's when a player who rolled through gets their
# swing in.
func _clearable_from_behind() -> bool:
	if _hit_landed:
		return false
	return _unparryable || animator.frame <= attack_frame

func _on_player_sword(from_direction: String) -> void:
	if !_combo.is_empty() && _animation_is("slash") && from_direction != direction \
			&& _hit() == Hit.KICK && _twinkled_at < 0 && !_swung_first():
		Juice.clank(true)
		player.mark_swing_parried() # Passes through, unblocked, rather than staggering
		return
	if !_combo.is_empty() && _animation_is("slash") && from_direction == direction && _hit_landed:
		# Its hit caught the player: the combo is over, and getting behind it now is just an
		# ordinary hit (not the daze a red attack's back otherwise gives, Enemy._on_player_sword).
		take_damage(from_direction, player.sword_damage())
		return
	if _combo.is_empty() || !_animation_is("slash") || from_direction != direction \
			|| !_clearable_from_behind():
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
				if _body_facing != "": # A taurtaur shows its fixed facing
					action = "slash_kick_top" if _kick_is_top() else "slash_kick"
					dir = _body_facing
			Hit.CHARGE:
				action = "slash_charge"
	super(action, dir)

func _twinkle_position() -> Vector2:
	if !_combo.is_empty():
		match _hit():
			Hit.KICK:
				if _body_facing != "":
					var tips: Dictionary = top_kick_tips if _kick_is_top() else kick_tips
					if tips.has(_body_facing):
						return tips[_body_facing]
				elif kick_tips.has(direction):
					return kick_tips[direction]
			Hit.CHARGE:
				if charge_tips.has(direction):
					return charge_tips[direction]
	return super()

func _on_staggered() -> void:
	super()
	_dashing = false
	_combo = PackedInt32Array()
	_body_facing = ""
	_parry_progress = 0.0 # Its combo bar runs out as it's stunned (Enemy fills it for others)

func _on_reset() -> void:
	super()
	_dashing = false
	_combo = PackedInt32Array()
	_body_facing = ""

# --- Taurtaur halves ---

# Kicking towards the side its bottom half faces, which only its top half's hind legs reach;
# otherwise its bottom half's hind legs kick out the other way.
func _kick_is_top() -> bool:
	return direction == _body_facing

# The top half's kick, from top_kick_sheet, added to its own copy of the animations.
func _add_top_kick_animations() -> void:
	if top_kick_sheet == "":
		return
	var frames := animator.sprite_frames.duplicate() as SpriteFrames
	var size := Vector2(TOP_KICK_FRAME)
	for dir: String in [Direction.RIGHT, Direction.LEFT, Direction.UP, Direction.DOWN]:
		var sheet := load(top_kick_sheet % dir) as Texture2D
		var anim := StringName("slash_kick_top_" + dir)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, frames.get_animation_speed(StringName("slash_kick_" + dir)))
		for i in int(sheet.get_width() / size.x):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(i * size.x, 0), size)
			frames.add_frame(anim, atlas)
	animator.sprite_frames = frames

# --- Charges ---

func _charging() -> bool:
	return !_combo.is_empty() && _hit() == Hit.CHARGE && _animation_is("slash")

# A taurtaur's lunge, up to its strike (Enemy.red_charge_coming).
func red_charge_coming() -> bool:
	return _charging() && _unparryable && animator.frame < attack_frame

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

# The parry bar's steps: one per hit of the combo (see Enemy._pilot_finishes_combo).
func _combo_hit_count() -> int:
	return maxi(_combo.size(), 1)

func _on_combo_left_to_pilot() -> void:
	super()
	_combo = PackedInt32Array()
	_dashing = false
