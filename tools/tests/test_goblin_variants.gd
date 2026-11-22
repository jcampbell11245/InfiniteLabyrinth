extends "res://tools/tests/test_case.gd"

# Hobgoblins (blow up on the player, flung when parried, blasts hurt enemies) and pilots
# (ride mounts, take hits before them, add a follow-up hit to each combo).

func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

static func first(room: Room, type: Variant) -> Enemy:
	for child in room.get_children():
		if is_instance_of(child, type) && !child.is_queued_for_deletion():
			return child
	return null

static func all_of(room: Room, type: Variant) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for child in room.get_children():
		if is_instance_of(child, type) && !child.is_queued_for_deletion():
			out.append(child)
	return out

func ridden_orc() -> Array:
	autoload("Tuning").pilot_spawn_chance = 0.0
	var design := RoomDesign.new()
	design.set_object(Vector2i(2, 2), "orc")
	design.set_pilot(Vector2i(2, 2), true)
	var room: Room = await boot_design(design)
	var orc: Enemy = null
	for child in room.get_children():
		if child is MeleeEnemy && child.mountable:
			orc = child
	return [room, orc, first(room, Pilot)]

func test_a_mount_set_to_start_with_a_pilot_has_one() -> void:
	var parts: Array = await ridden_orc()
	var room: Room = parts[0]
	var orc: Enemy = parts[1]
	var pilot: Pilot = parts[2]
	expect(pilot != null, "a pilot was made")
	if pilot == null:
		return
	expect(orc.rider == pilot && pilot.mount == orc, "riding the orc")
	expect_equal(room.enemy_count, 2, "the pilot counts towards clearing the room")

func test_the_pilot_takes_hits_before_its_mount() -> void:
	var parts: Array = await ridden_orc()
	var orc: Enemy = parts[1]
	var pilot: Pilot = parts[2]
	var orc_health := orc.health
	var pilot_health := pilot.health
	orc._lose_health(1.0, false)
	expect_equal(orc.health, orc_health, "the orc is untouched")
	expect_near(pilot.health, pilot_health - 1.0, 0.001, "the pilot took the hit")
	orc._lose_health(5.0, false) # Kills the pilot; the rest doesn't carry on
	expect(pilot.is_queued_for_deletion(), "the pilot is dead")
	expect(orc.rider == null, "and off the orc")
	expect_equal(orc.health, orc_health, "the orc still untouched")
	orc._lose_health(1.0, false)
	expect_near(orc.health, orc_health - 1.0, 0.001, "now the orc takes hits")

func test_a_finished_combo_gets_a_pilot_follow_up_unless_a_hit_landed() -> void:
	var parts: Array = await ridden_orc()
	var orc: Enemy = parts[1]
	var pilot: Pilot = parts[2]
	orc._combo_finished()
	expect(pilot._strike_pending, "the pilot follows up")
	pilot._strike_pending = false
	orc.landed_hit()
	orc._combo_finished()
	expect(!pilot._strike_pending, "no follow-up after a hit landed")

func test_a_mount_that_dies_drops_its_pilot() -> void:
	var parts: Array = await ridden_orc()
	var orc: Enemy = parts[1]
	var pilot: Pilot = parts[2]
	orc.fall()
	expect(pilot.mount == null && !pilot.is_queued_for_deletion(), "the pilot jumps off, alive")
	await tree.process_frame # The hurtbox comes back on deferred
	expect(!pilot.hurtbox.disabled, "and can be hit again")

func test_a_pilot_on_foot_climbs_onto_a_free_mount() -> void:
	autoload("Tuning").pilot_spawn_chance = 0.0
	autoload("Tuning").pilot_mount_chance = 1.0 # Always decides to go for a mount
	var design := RoomDesign.new()
	design.set_object(Vector2i(2, 2), "orc")
	design.set_object(Vector2i(4, 2), "pilot")
	var room: Room = await boot_design(design)
	var pilot: Pilot = first(room, Pilot)
	for i in 30:
		await tree.physics_frame
	expect(pilot.mount == null, "not before it has noticed the player")
	pilot.noticed = true
	for i in 180:
		if pilot.mount != null:
			break
		await tree.physics_frame
	expect(pilot.mount != null && pilot.mount.mountable, "it climbed on")

func test_a_hobgoblin_blast_hurts_enemies_but_a_flung_one_spares_the_player() -> void:
	autoload("Tuning").hobgoblin_blast_enemy_damage = 1.0
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	design.set_object(Vector2i(7, 6), "goblin")
	var room: Room = await boot_design(design)
	var hobgoblin: Hobgoblin = first(room, Hobgoblin)
	var goblin: Enemy = null
	for child in room.get_children():
		if child is MeleeEnemy && !(child is Hobgoblin):
			goblin = child
	var before := goblin.health
	var player: Player = autoload("Game").player
	player.global_position = hobgoblin.global_position + Vector2(10, 0)
	hobgoblin.explode(false)
	expect(hobgoblin.is_queued_for_deletion(), "it dies in its blast")
	expect_near(goblin.health, before - 1.0, 0.001, "the goblin beside it is hurt")
	expect_equal(player.invincibility_cooldown.time_left, 0.0, "the player isn't")

func test_a_hobgoblin_touching_the_player_hurts_them() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	var room: Room = await boot_design(design)
	var hobgoblin: Hobgoblin = first(room, Hobgoblin)
	var player: Player = autoload("Game").player
	hobgoblin.global_position = player.global_position + Vector2(8, 0)
	hobgoblin.explode(true)
	expect(player.invincibility_cooldown.time_left > 0, "the player was hit")

func test_a_parried_hobgoblin_is_flung_the_way_the_sword_travels() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	var room: Room = await boot_design(design)
	var hobgoblin: Hobgoblin = first(room, Hobgoblin)
	var player: Player = autoload("Game").player
	hobgoblin._light_fuse()
	player.swing_started_at = Time.get_ticks_msec() # Swung on its glint
	player.swing_started_frame = Engine.get_physics_frames() + 1
	hobgoblin._on_player_sword(Direction.LEFT)
	expect(hobgoblin._flung, "flung")
	expect_equal(hobgoblin._fling_dir, Vector2.LEFT, "the way the sword travelled")

func test_one_blast_sets_off_the_hobgoblins_in_it() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	design.set_object(Vector2i(7, 6), "hobgoblin")
	var room: Room = await boot_design(design)
	var both := all_of(room, Hobgoblin)
	(both[0] as Hobgoblin).explode(false)
	await tree.process_frame
	await tree.process_frame
	expect(!is_instance_valid(both[1]) || both[1].is_queued_for_deletion(), "the second went off too")

func test_the_room_creator_saves_pilots() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(1, 1), "wyrm")
	design.set_object(Vector2i(2, 1), "goblin")
	design.set_pilot(Vector2i(1, 1), true)
	design.set_pilot(Vector2i(2, 1), true)
	expect(design.has_pilot(Vector2i(1, 1)), "a dragon can carry a pilot")
	expect(!design.has_pilot(Vector2i(2, 1)), "a goblin can't")
	var text := design.to_text()
	expect(text.contains("pilot:\n1,1\n"), "exported")
	design.set_object(Vector2i(1, 1), "goblin")
	expect(!design.has_pilot(Vector2i(1, 1)), "replacing the mount drops its pilot")

func test_every_mount_kind_can_carry_a_pilot() -> void:
	for kind: String in RoomDesign.MOUNT_KINDS:
		var enemy: Enemy = (load(RoomDesign.OBJECT_SCENES[kind]) as PackedScene).instantiate()
		expect(enemy.mountable, "%s is mountable" % kind)
		enemy.free()

func test_a_hobgoblin_that_reaches_the_player_goes_off_after_its_glint() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	var room: Room = await boot_design(design)
	var hobgoblin: Hobgoblin = first(room, Hobgoblin)
	var player: Player = autoload("Game").player
	hobgoblin.global_position = player.global_position + Vector2(10, 0)
	hobgoblin._light_fuse()
	expect(hobgoblin.is_fusing(), "it glints at once")
	await wait_real(autoload("Tuning").parry_window + 0.2)
	expect(!is_instance_valid(hobgoblin) || hobgoblin.is_queued_for_deletion(), "then goes off")
	expect(player.invincibility_cooldown.time_left > 0, "catching the player")

func test_a_cleared_combo_leaves_the_stun_to_the_pilot() -> void:
	var parts: Array = await ridden_orc()
	var orc: MeleeEnemy = parts[1]
	var pilot: Pilot = parts[2]
	var player: Player = autoload("Game").player
	orc.global_position = player.global_position + Vector2(20, 0)
	pilot._ride()
	expect(orc._pilot_finishes_combo(), "the pilot takes the combo's last hit")
	expect(!orc.is_stunned(), "so the orc isn't stunned yet")
	expect(pilot.follow_up_coming(), "the pilot is about to slash")
	expect_near(orc._parry_progress, 0.5, 0.001, "the bar shows one hit of two cleared")

func test_parrying_the_pilot_slash_stuns_its_mount() -> void:
	var parts: Array = await ridden_orc()
	var orc: MeleeEnemy = parts[1]
	var pilot: Pilot = parts[2]
	var player: Player = autoload("Game").player
	orc.global_position = player.global_position + Vector2(20, 0)
	pilot._ride()
	pilot._start_strike()
	pilot._twinkle() # Its glint, now
	player.swing_started_at = Time.get_ticks_msec()
	player.swing_started_frame = Engine.get_physics_frames() + 1
	expect(pilot.meets_sword(Direction.RIGHT), "the sword meets the pilot's slash")
	expect(orc.is_stunned(), "and the orc is stunned")

func test_a_fireball_the_player_didnt_parry_gets_no_pilot_slash() -> void:
	autoload("Tuning").pilot_spawn_chance = 0.0
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 3), "wyrm")
	design.set_pilot(Vector2i(6, 3), true)
	var room: Room = await boot_design(design)
	var wyrm: Wyrm = first(room, Wyrm)
	var pilot: Pilot = wyrm.rider
	wyrm._end_attack(0.0, false, false) # How a fireball that played out ends
	expect(!pilot.follow_up_coming(), "no slash after an unparried fireball")
	wyrm._end_attack(0.0) # How a charge ends
	expect(pilot._strike_pending, "a charge gets one")

func test_a_returned_fireball_only_hurts_the_pilot() -> void:
	var parts: Array = await ridden_orc()
	var room: Room = parts[0]
	var orc: Enemy = parts[1]
	var pilot: Pilot = parts[2]
	var before := orc.health
	var shot: Projectile = (load("res://src/projectiles/Fireball.tscn") as PackedScene).instantiate()
	shot.damage = 1.0
	room.add_child(shot)
	shot.global_position = orc.global_position + Vector2(0, 60)
	shot.direction = Direction.UP
	shot.deflect(Direction.UP) # Sent back by the player: 1.5 damage, enough for the pilot
	for i in 90:
		await tree.physics_frame
	expect(!is_instance_valid(pilot) || pilot.is_queued_for_deletion(), "the pilot is dead")
	expect_equal(orc.health, before, "the orc isn't hurt by the same shot")

func test_a_pilot_that_saw_the_player_makes_its_mount_notice_them() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(10, 10), "orc")
	design.set_radius(Vector2i(10, 10), 0)
	design.set_object(Vector2i(10, 8), "pilot")
	var room: Room = await boot_design(design)
	var pilot: Pilot = first(room, Pilot)
	var orc: MeleeEnemy = null
	for child in room.get_children():
		if child is MeleeEnemy && child.mountable:
			orc = child
	orc.noticed = false
	pilot.noticed = true
	pilot.mount_on(orc)
	expect(orc.noticed, "the orc notices the player")

func test_a_hobgoblin_stops_dead_as_it_reaches_the_player() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "hobgoblin")
	var room: Room = await boot_design(design)
	var hobgoblin: Hobgoblin = first(room, Hobgoblin)
	var player: Player = autoload("Game").player
	hobgoblin.noticed = true
	hobgoblin.global_position = player.global_position + Vector2(60, 0)
	for i in 120:
		if hobgoblin.is_fusing():
			break
		await tree.physics_frame
	expect(hobgoblin.is_fusing(), "it reached the player and glinted")
	var gap := hobgoblin._gap_to_player()
	expect(gap > -2.0 && gap <= autoload("Tuning").hobgoblin_contact_reach + 2.0,
		"it stopped at its body's edge, not inside the player (gap %.1f)" % gap)
	var at := hobgoblin.global_position
	await tree.physics_frame
	await tree.physics_frame
	expect(hobgoblin.global_position.distance_to(at) < 0.5, "and stays put while it glints")

func test_a_riding_pilot_doesnt_walk() -> void:
	var parts: Array = await ridden_orc()
	var pilot: Pilot = parts[2]
	pilot._moving = true # As if it was walking when it climbed on
	for i in 3: # A physics frame to sit it down, then a process frame to animate it
		await tree.process_frame
	expect(!String(pilot.animator.animation).begins_with("walk"), "no walk cycle while riding")

func test_a_dragon_holds_still_while_its_pilot_finishes_the_combo() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 3), "wyrm")
	design.set_pilot(Vector2i(6, 3), true)
	var room: Room = await boot_design(design)
	var wyrm: Wyrm = first(room, Wyrm)
	var pilot: Pilot = wyrm.rider
	var player: Player = autoload("Game").player
	wyrm.global_position = player.global_position + Vector2(20, 0)
	pilot._ride()
	expect(wyrm._pilot_finishes_combo(), "the pilot takes the last hit")
	await wait_real(autoload("Tuning").wyrm_charge_recovery + 0.15)
	expect(pilot.follow_up_coming(), "the pilot is still on its slash")
	expect(!wyrm._in_rollable_recovery(), "hanging for the pilot isn't a red charge's recovery")
	var at := wyrm.global_position
	await tree.physics_frame
	await tree.physics_frame
	expect(wyrm.global_position.distance_to(at) < 0.5, "the dragon stays put meanwhile")
