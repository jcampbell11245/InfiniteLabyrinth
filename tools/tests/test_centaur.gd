extends "res://tools/tests/test_case.gd"

# Centaurs (Centaur.gd): each test plays a one-room design with a centaur, bucentaur or
# taurtaur in it, as the room creator's play-test does, and drives its attacks directly to
# check how combos chain, end and stun, and how charges and group rushes go.

const CENTAUR_AT := Vector2i(6, 6)
const CLASH := Centaur.Hit.CLASH
const KICK := Centaur.Hit.KICK

func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

func player() -> Player:
	return autoload("Game").player

func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame

# A room with one `kind` of centaur in it, and the centaur, with the player standing in
# reach of it (so its combos don't break off).
func boot_centaur(kind: String, design := RoomDesign.new()) -> Centaur:
	design.set_object(CENTAUR_AT, kind)
	design.set_facing(CENTAUR_AT, Direction.LEFT)
	design.set_radius(CENTAUR_AT, RoomDesign.RADIUS_MAX)
	var room: Room = await boot_design(design)
	for child in room.get_children():
		if child is Centaur:
			player().global_position = child.global_position + Vector2(-child._engage_distance(true), 0)
			return child
	return null

# Gives it just the one combo, and no charges.
func only_combo(centaur: Centaur, hits: Array) -> void:
	var combo := PackedInt32Array(hits)
	centaur.combos.assign([combo])
	centaur.charge = Centaur.Charge.NONE

# Waits (up to `limit` physics frames) for the hit under way to spark.
func wait_for_spark(centaur: Centaur, limit := 300) -> void:
	for i in limit:
		if centaur._twinkled_at >= 0:
			return
		await tree.physics_frame

# A sword swing begun now, meeting it now: a parry if the spark has shown.
func swing_at(centaur: Centaur) -> void:
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	centaur._on_player_sword({Direction.LEFT: Direction.RIGHT, Direction.RIGHT: Direction.LEFT,
		Direction.UP: Direction.DOWN, Direction.DOWN: Direction.UP}[centaur.direction])

# Waits (up to `limit` physics frames) for the hit under way to give way to the next one,
# or for the attack to end.
func wait_for_hit_after(centaur: Centaur, index: int, limit := 300) -> void:
	for i in limit:
		if centaur._combo.is_empty() || centaur._combo_index > index:
			return
		await tree.physics_frame

func test_scenes_have_their_attacks() -> void:
	for scene: String in ["Centaur", "Bucentaur", "Taurtaur"]:
		var centaur: Centaur = (load("res://src/enemies/%s.tscn" % scene) as PackedScene).instantiate()
		expect_equal(centaur.health, 2.5, "%s has a knight's health" % scene)
		expect(!centaur.combos.is_empty(), "%s has combos" % scene)
		centaur.free()

# Parried clashes and a dodged kick carry it through the combo; only clearing it all stuns it.
func test_clearing_a_combo_stuns_it() -> void:
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH, CLASH, KICK, CLASH])
	centaur._start_swing(true)
	for index in 2: # The two clashes, parried
		await wait_for_spark(centaur)
		swing_at(centaur)
		await tree.physics_frame
		expect(!centaur.is_stunned(), "parrying clash %d doesn't stun it" % (index + 1))
		expect_equal(centaur._combo_index, index + 1, "it goes on to the next hit")
	expect(centaur._unparryable, "the third hit is a kick: a red spark")
	expect(String(centaur.animator.animation).begins_with("slash_kick"), "it turns to kick")
	await wait_for_spark(centaur)
	swing_from_behind(centaur) # Rolled through it and hit its back
	await tree.physics_frame
	expect_equal(centaur._combo_index, 3, "the kick hit from behind goes on to the last clash")
	expect(!centaur.is_stunned(), "still not stunned")
	await wait_for_spark(centaur)
	swing_at(centaur)
	await tree.physics_frame
	expect(centaur.is_stunned(), "parrying the last clash stuns it")

func test_an_unparried_clash_ends_the_combo() -> void:
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH, CLASH, KICK])
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	await wait_for_hit_after(centaur, 0)
	expect(centaur._combo.is_empty(), "the combo is over")
	expect(!centaur.is_stunned(), "with no stun")

# A kick that plays out (dodged, or landing) carries the combo on, but isn't cleared: only a
# hit on its back clears it.
func test_a_kick_that_plays_out_carries_the_combo_on() -> void:
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	await wait_for_hit_after(centaur, 0)
	expect_equal(centaur._combo_index, 1, "on to the next kick")
	expect_near(centaur._parry_progress, 0.0, 0.01, "with nothing cleared on the bar")
	for i in 400:
		if centaur._combo.is_empty():
			break
		await tree.physics_frame
	expect(centaur._combo.is_empty(), "the combo plays out")
	expect(!centaur.is_stunned(), "and dodging the rest doesn't stun it")

# It takes a hit for every hit of the combo: three hits on its back for three kicks.
func test_hitting_the_back_of_every_kick_stuns_a_taurtaur() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	centaur._start_swing(true)
	for index in 3:
		expect(!centaur.is_stunned(), "not stunned before hit %d" % (index + 1))
		await wait_for_spark(centaur)
		swing_from_behind(centaur)
		await tree.process_frame
	expect(centaur.is_stunned(), "the third hit stuns it")

# Dodging every kick, without hitting its back, doesn't stun it.
func test_dodging_every_kick_doesnt_stun() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	var stunned := false
	for i in 500:
		stunned = stunned || centaur.is_stunned()
		if centaur._combo.is_empty():
			break
		await tree.physics_frame
	expect(centaur._combo.is_empty(), "the combo plays out")
	expect(!stunned, "without stunning it")

func test_an_early_swing_at_a_kick_is_blocked() -> void:
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	swing_at(centaur)
	await physics_frames(2)
	expect(!centaur.is_stunned(), "a kick can't be parried")
	expect(player().is_dazed(), "the swing is blocked and staggers the player")

func test_group_rush_strike_is_a_single_clash() -> void:
	for kind: String in ["centaur", "taurtaur"]:
		var centaur := await boot_centaur(kind)
		centaur.begin_group_rush(Vector2.RIGHT)
		centaur.rush_strike()
		expect_equal(centaur._combo, PackedInt32Array([CLASH]), "%s rushes in with one clash" % kind)
		expect(!centaur._unparryable, "%s's rush strike can be parried" % kind)

func test_each_hit_has_its_own_damage() -> void:
	var tuning := autoload("Tuning")
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH, KICK])
	centaur._start_swing(true)
	expect_near(centaur.melee_damage(), tuning.centaur_clash_damage, 0.001, "a clash")
	centaur._combo_index = 1
	expect_near(centaur.melee_damage(), tuning.centaur_kick_damage, 0.001, "a kick")

func test_kick_sparks_at_the_hooves() -> void:
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [KICK])
	centaur._start_swing(true)
	expect_equal(centaur._twinkle_position(), centaur.kick_tips[centaur.direction], "kick spark")
	only_combo(centaur, [CLASH])
	centaur._start_swing(true)
	expect_equal(centaur._twinkle_position(), centaur.weapon_tips[centaur.direction], "clash spark")

# A Bucentaur's charge holds, sparks white as it sets off, gallops at the player and can be
# parried by a swing begun after the spark.
func test_bucentaur_charge_can_be_parried() -> void:
	autoload("Tuning").centaur_charge_chance = 1.0
	var centaur := await boot_centaur("bucentaur")
	var start := centaur.global_position
	centaur._start_swing(true)
	expect_equal(centaur._combo, PackedInt32Array(Centaur.CHARGE_COMBO), "it charges")
	await wait_for_spark(centaur)
	expect(centaur._dashing, "sparking as it sets off")
	expect(!centaur._unparryable, "a white spark")
	await physics_frames(3)
	expect(centaur.global_position.distance_to(start) > 4.0, "galloping at the player")
	swing_at(centaur)
	await tree.physics_frame
	expect(!centaur.is_stunned(), "a swing begun after the spark parries it, but doesn't stun it yet")
	expect_equal(centaur._combo_index, 1, "a clash follows the charge")
	await wait_for_spark(centaur)
	swing_at(centaur)
	await tree.physics_frame
	expect(centaur.is_stunned(), "parrying the clash after the charge stuns it")

func test_bucentaur_charge_into_a_rock_dazes_it() -> void:
	autoload("Tuning").centaur_charge_chance = 1.0
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.STALAGMITE)
	var centaur := await boot_centaur("bucentaur", design)
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	expect(centaur._dashing, "it sets off")
	# Put it just beside the rock, running at it.
	var rock := centaur.room.to_global(RoomDesign.cell_centre(Vector2i(4, 6)))
	centaur.global_position += rock + Vector2(26, 0) - centaur.feet_position()
	centaur._charge_dir = Vector2.LEFT
	for i in 60:
		if centaur.is_stunned():
			break
		await tree.physics_frame
	expect(centaur.is_stunned(), "slamming into the rock dazes it")

# A Taurtaur's lunge sparks red, can't be parried, and leaves it frozen in end lag.
func test_taurtaur_lunge_is_roll_only() -> void:
	autoload("Tuning").centaur_charge_chance = 1.0
	var centaur := await boot_centaur("taurtaur")
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	expect(centaur._unparryable, "a red spark")
	var lagged := false
	for i in 300:
		if centaur.in_end_lag():
			lagged = true
			break
		await tree.physics_frame
	expect(lagged, "it stands frozen afterwards")
	expect(!centaur.is_stunned(), "but isn't stunned")
	for i in 300:
		if centaur._combo_index == 1:
			break
		await tree.physics_frame
	expect_equal(centaur._combo_index, 1, "then a clash (a stomp) follows")
	expect(!centaur._unparryable, "which can be parried")
	await wait_for_spark(centaur)
	swing_at(centaur)
	await tree.physics_frame
	expect(!centaur.is_stunned(), "and parrying it isn't enough, the lunge wasn't hit")

# Hitting the lunge's back, then parrying the clash after it, stuns it.
func test_taurtaur_lunge_hit_from_behind_then_clash_stuns() -> void:
	autoload("Tuning").centaur_charge_chance = 1.0
	var centaur := await boot_centaur("taurtaur")
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	var facing := centaur.direction
	swing_from_behind(centaur)
	await tree.process_frame
	expect_equal(centaur._combo_index, 1, "the lunge is cleared, on to the clash")
	expect_equal(centaur.direction, facing, "without its sides swapping (only kicks do)")
	await wait_for_spark(centaur)
	swing_at(centaur)
	await tree.physics_frame
	expect(centaur.is_stunned(), "parrying the clash then stuns it")

func test_centaur_combos() -> void:
	var centaur: Centaur = (load("res://src/enemies/Centaur.tscn") as PackedScene).instantiate()
	expect(centaur.combos.has(PackedInt32Array([KICK, CLASH, KICK])), "its short combo is kick, clash, kick")
	expect(centaur.combos.has(PackedInt32Array([CLASH, CLASH, KICK, CLASH])), "its long one clash, clash, kick, clash")
	centaur.free()

# Where it can be hit follows the drawn body, frame by frame.
func test_hurtbox_follows_the_sprite() -> void:
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [KICK])
	await tree.process_frame
	var idle_size: Vector2 = (centaur.hurtbox.shape as RectangleShape2D).size
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	await tree.process_frame
	var anim := String(centaur.animator.animation)
	var drawn: Rect2 = centaur.sprite_bounds[anim][centaur.animator.frame]
	var standing: Rect2 = centaur.sprite_bounds["idle_" + centaur.direction][0]
	var margin: float = autoload("Tuning").centaur_hurtbox_margin
	var expected := drawn.merge(standing).grow(margin)
	expect_equal((centaur.hurtbox.shape as RectangleShape2D).size, expected.size, "the hurtbox covers the drawn body, at least the standing one, padded")
	expect_equal(centaur.hurtbox.position, expected.get_center(), "and sits on it")
	expect((centaur.hurtbox.shape as RectangleShape2D).size != idle_size, "which changes as it kicks")

# A player who gets away mid-combo breaks it off: no stun, and it starts over.
func test_getting_away_breaks_off_the_combo() -> void:
	var tuning := autoload("Tuning")
	tuning.centaur_chase_charge_chance = 0.0 # Walks back up
	tuning.centaur_charge_chance = 0.0 # Opens with the combo
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	centaur.charge = Centaur.Charge.ROLL
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	player().global_position = centaur.global_position + Vector2(-150, 0) # Far off
	await wait_for_hit_after(centaur, 0)
	expect(centaur._combo.is_empty(), "the combo is dropped")
	expect(!centaur.is_stunned(), "with no stun")
	expect(centaur._skip_charge, "and its next attack is a fresh combo")

func test_getting_away_from_a_charger_may_set_it_charging() -> void:
	var tuning := autoload("Tuning")
	tuning.centaur_chase_charge_chance = 1.0
	tuning.centaur_charge_chance = 0.0 # Opens with the combo
	var centaur := await boot_centaur("bucentaur")
	only_combo(centaur, [CLASH, CLASH, KICK, CLASH])
	centaur.charge = Centaur.Charge.CLASH
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	# Parried, with the player already backing off out of reach (the next hit would start
	# at the parry).
	player().global_position = centaur.global_position + Vector2(-150, 0)
	swing_at(centaur)
	await tree.physics_frame
	await tree.physics_frame
	expect_equal(centaur._combo, PackedInt32Array(Centaur.CHARGE_COMBO), "it charges instead of going on")
	expect(!centaur.is_stunned(), "and the parry didn't stun it")

# A sword hit from behind (travelling the way it faces), as the player rolls through a kick.
func swing_from_behind(centaur: Centaur) -> void:
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	centaur._on_player_sword(centaur.direction)

# Mid-combo, a hit from behind clears the hit it's on instead of hurting: on to the next.
func test_back_hit_clears_a_hit_without_damage() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	var health := centaur.health
	swing_from_behind(centaur)
	await tree.process_frame
	expect_equal(centaur.health, health, "no damage")
	expect_equal(centaur._combo_index, 1, "it's on to the next kick")
	expect_near(centaur._parry_progress, 1.0 / 3.0, 0.01, "the combo bar moves a step")
	expect(!centaur.is_stunned(), "not stunned yet")

func test_back_hit_before_the_spark_does_nothing() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	centaur._start_swing(true)
	var health := centaur.health
	swing_from_behind(centaur) # Still winding up, no spark yet
	await tree.process_frame
	expect_equal(centaur.health, health, "no damage")
	expect_equal(centaur._combo_index, 0, "the kick isn't cleared")

func test_back_hit_on_the_last_hit_stuns_it() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK])
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	var health := centaur.health
	swing_from_behind(centaur)
	await tree.process_frame
	expect(centaur.is_stunned(), "clearing the last hit from behind stuns it")
	expect_equal(centaur.health, health, "without hurting it")
	expect_near(centaur._parry_progress, 1.0, 0.01, "the combo bar is full")

func test_back_hit_outside_a_combo_hurts() -> void:
	var centaur := await boot_centaur("centaur")
	await physics_frames(2)
	centaur._end_windup_hold()
	centaur._play("idle")
	centaur._combo = PackedInt32Array()
	var health := centaur.health
	swing_from_behind(centaur)
	await tree.process_frame
	expect(centaur.health < health, "an ordinary hit")

func test_parried_clash_moves_the_combo_bar_a_step() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH, CLASH, KICK, CLASH])
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	swing_at(centaur)
	await tree.process_frame
	expect_near(centaur._parry_progress, 0.25, 0.01, "a quarter of the way")

# Rolling through a clash as it strikes gets clear: it doesn't swing round after the player,
# and the follow-through doesn't hurt.
func test_rolling_through_a_clash_gets_clear() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH, CLASH, KICK, CLASH])
	var p := player()
	var health_before := p.invincibility_cooldown.time_left
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	Input.action_press("right")
	await tree.physics_frame
	Input.action_press("roll")
	await tree.physics_frame
	Input.action_release("roll")
	var hit := false
	var last := health_before
	var struck_facing := ""
	for i in 60:
		await tree.physics_frame
		if i == 20:
			Input.action_release("right")
		if struck_facing == "" && centaur._animation_is("slash") && centaur.animator.frame == centaur.attack_frame:
			struck_facing = centaur.direction
		var left := p.invincibility_cooldown.time_left
		if left > last + 0.05: # Hurt: a fresh invincibility
			hit = true
		last = left
	Input.action_release("right")
	expect(!hit, "the player rolled through without being hit")
	expect_equal(struck_facing, Direction.LEFT, "it struck the way it faced at the spark")

func test_only_the_strike_frame_hurts() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("centaur")
	only_combo(centaur, [CLASH])
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	var live_after := false
	var live_on := false
	for i in 300:
		if centaur._animation_is("slash") && centaur.animator.frame == centaur.attack_frame && !centaur.hitbox.disabled:
			live_on = true
		if centaur._animation_is("slash") && centaur.animator.frame > centaur.attack_frame && !centaur.hitbox.disabled:
			live_after = true
		if live_on && !centaur._animation_is("slash"):
			break
		await tree.physics_frame
	expect(live_on, "the strike frame hurts")
	expect(!live_after, "the follow-through doesn't")

# A taurtaur keeps its facing through a kick combo: its bottom half's hind legs kick first,
# then its top half's on the far side, swapping with every kick.
func test_taurtaur_kicks_alternate_halves_without_turning() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK, KICK, KICK])
	player().invincibility_cooldown.start(100.0)
	centaur._start_swing(true)
	var body := centaur._body_facing
	expect_equal(body, Direction.RIGHT, "its bottom half faces away from the player (on its left)")
	expect_equal(String(centaur.animator.animation), "slash_kick_right", "the bottom half kicks first")
	await wait_for_spark(centaur)
	expect_equal(centaur._twinkle_position(), centaur.kick_tips[body], "sparking at the bottom half's hind hooves")
	await wait_for_hit_after(centaur, 0) # Played out, not hit
	expect_equal(centaur._body_facing, body, "it hasn't turned round")
	expect_equal(centaur.direction, Direction.RIGHT, "the next kick goes to the other side")
	expect_equal(String(centaur.animator.animation), "slash_kick_top_right", "from its top half")
	expect_equal(centaur._twinkle_position(), centaur.top_kick_tips[body], "sparking at the top half's hind hooves")
	await wait_for_spark(centaur)
	swing_from_behind(centaur) # A hit on its back swaps the side just once
	await tree.process_frame
	expect_equal(centaur.direction, Direction.LEFT, "the third kick comes back round")
	expect_equal(String(centaur.animator.animation), "slash_kick_right", "from its bottom half")

func test_taurtaur_faces_as_usual_after_a_combo() -> void:
	autoload("Tuning").centaur_charge_chance = 0.0
	var centaur := await boot_centaur("taurtaur")
	only_combo(centaur, [KICK])
	centaur._start_swing(true)
	await wait_for_spark(centaur)
	swing_from_behind(centaur) # Clears it: stunned
	await tree.process_frame
	expect(centaur.is_stunned(), "stunned")
	expect_equal(centaur._body_facing, "", "back to its usual facing")

# Anything it starts during a group rush is a single clash, even a counter.
func test_anything_during_a_group_rush_is_one_clash() -> void:
	var centaur := await boot_centaur("taurtaur")
	var coordinator := AttackCoordinator.for_room(centaur.room)
	coordinator._rushers.append(centaur) # A rush under way
	centaur._start_swing(true) # As a counter would
	expect_equal(centaur._combo, PackedInt32Array([CLASH]), "one clash")
	coordinator._rushers.clear()

# A centaur that can charge may open with one from well out of reach.
func test_charges_from_afar() -> void:
	var tuning := autoload("Tuning")
	tuning.centaur_charge_chance = 1.0
	var centaur := await boot_centaur("bucentaur")
	centaur.attack_cooldown.stop()
	player().global_position = centaur.global_position + Vector2(-120, 0)
	var charged := false
	for i in 60:
		await tree.physics_frame
		if !centaur._combo.is_empty() && centaur._combo[0] == Centaur.Hit.CHARGE:
			charged = true
			break
	expect(charged, "it charges from 120 px off instead of walking up")
