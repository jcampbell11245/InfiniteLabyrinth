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
	var design := RoomDesign.new()
	design.set_object(Vector2i(2, 2), "orc")
	design.set_object(Vector2i(4, 2), "pilot")
	var room: Room = await boot_design(design)
	var pilot: Pilot = first(room, Pilot)
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
	hobgoblin._lunging = true
	hobgoblin._lunge_started_at = player.swing_started_at # Swung on (not before) its leap
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
