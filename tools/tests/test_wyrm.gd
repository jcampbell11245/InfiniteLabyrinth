extends "res://tools/tests/test_case.gd"

# Dragons (Wyrm.gd): each test plays a one-room design with a wyrm or wyvern in it, as the
# room creator's play-test does, and checks how it flies, circles, charges and breathes fire.

const SPAWN := Vector2i(0, 6) # Where the play-test puts the player in an empty design
const DRAGON_AT := Vector2i(10, 6)

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

# A room with one `kind` of dragon in it, and the dragon. Unless `wary` is false it faces the
# player's spawn and sees the whole room, so it notices them at once.
func boot_dragon(kind: String, design := RoomDesign.new(), wary := true) -> Wyrm:
	design.set_object(DRAGON_AT, kind)
	if wary:
		design.set_facing(DRAGON_AT, Direction.LEFT)
		design.set_radius(DRAGON_AT, RoomDesign.RADIUS_MAX)
	var room: Room = await boot_design(design)
	for child in room.get_children():
		if child is Wyrm:
			return child
	return null

# Never attacks, so it only circles.
func calm() -> void:
	var tuning := autoload("Tuning")
	tuning.wyrm_attack_cooldown_min = 1000.0
	tuning.wyrm_attack_cooldown_max = 1000.0

# Attacks straight away, always the same way.
func eager(charge: bool) -> void:
	var tuning := autoload("Tuning")
	tuning.wyrm_attack_cooldown_min = 0.0
	tuning.wyrm_attack_cooldown_max = 0.0
	tuning.wyrm_charge_chance = 1.0 if charge else 0.0

# Waits (up to `limit` physics frames) for the dragon's charge to glint.
func wait_for_glint(dragon: Wyrm, limit := 300) -> void:
	for i in limit:
		if dragon._twinkled_at >= 0:
			return
		await tree.physics_frame

func test_flies_over_pits_and_traps() -> void:
	calm()
	var design := RoomDesign.new()
	design.set_cell(Vector2i(10, 2), RoomDesign.Cell.SPIKES)
	var wyrm := await boot_dragon("wyrm", design)
	expect(wyrm != null, "the wyrm is in the room")
	expect(wyrm.flies(), "wyrms fly")
	expect_equal(wyrm.collision_mask & (1 << (Constants.Layer.PITFALL - 1)), 0, "pits don't stop it")
	var room := wyrm.room
	var health := wyrm.health
	wyrm.global_position += room.to_global(RoomDesign.cell_centre(Vector2i(10, 2))) - wyrm.feet_position()
	await physics_frames(10)
	expect_equal(wyrm.health, health, "spikes under it don't hurt it")

func test_waits_to_notice_the_player_before_attacking() -> void:
	eager(true)
	var wyrm := await boot_dragon("wyrm", RoomDesign.new(), false) # Faces right, default radius
	var start := wyrm.global_position
	await physics_frames(60)
	expect(!wyrm.noticed, "doesn't notice a player behind it, out of range")
	expect(!wyrm._animation_is("slash") && !wyrm._animation_is("shoot"), "and doesn't attack")
	expect(wyrm.global_position.distance_to(start) < 1.0, "it hovers where it started")
	# Behind it but within range still isn't seen...
	player().global_position = wyrm.global_position + Vector2(-40, 0)
	await physics_frames(5)
	expect(!wyrm.noticed, "the player can sneak up behind it")
	# ...in front of it is.
	player().global_position = wyrm.global_position + Vector2(40, 0)
	await physics_frames(5)
	expect(wyrm.noticed, "notices a player in front, within its radius")

func test_charging_into_a_rock_dazes_it() -> void:
	eager(true)
	var design := RoomDesign.new()
	design.set_cell(Vector2i(7, 6), RoomDesign.Cell.STALAGMITE)
	var wyrm := await boot_dragon("wyrm", design)
	var room := wyrm.room
	# It circles before charging, so wherever it sets off from, put it in line with the rock,
	# just to its right, charging left at a player beyond it.
	for i in 300:
		if wyrm._dashing:
			break
		await tree.physics_frame
	expect(wyrm._dashing, "it sets off on a charge")
	player().global_position = room.to_global(RoomDesign.cell_centre(Vector2i(2, 6))) - Player.FEET
	var beside_rock := room.to_global(RoomDesign.cell_centre(Vector2i(7, 6)) + Vector2(Room.CELL_SIZE * 1.5, 0))
	wyrm.global_position += beside_rock - wyrm.feet_position()
	wyrm._charge_dir = Vector2.LEFT
	wyrm._dash_left = Room.CELL_SIZE * 4.0
	for i in 60:
		if wyrm.is_stunned():
			break
		await tree.physics_frame
	expect(wyrm.is_stunned(), "slamming into the stalagmite stuns it")
	expect(wyrm.is_vulnerable(), "and its next hit taken is multiplied, as after a parry")
	expect(!wyrm._animation_is("slash"), "the charge is over")

func test_circles_the_player() -> void:
	calm()
	var wyrm := await boot_dragon("wyrm")
	player().global_position = wyrm.room.to_global(RoomDesign.cell_centre(Vector2i(6, 6))) - Player.FEET
	await wait_real(2.5)
	var distance := wyrm.global_position.distance_to(player().global_position)
	expect_near(distance, autoload("Tuning").wyrm_orbit_radius, 12.0, "circles at the orbit radius")

func test_charge_glints_near_the_player_and_can_be_parried() -> void:
	eager(true)
	var wyrm := await boot_dragon("wyrm")
	await wait_for_glint(wyrm)
	expect(wyrm._twinkled_at >= 0, "the charge glints")
	expect(!wyrm._unparryable, "a wyrm's charge can be parried")
	var tuning := autoload("Tuning")
	var lead: float = tuning.wyrm_charge_speed * tuning.parry_window / 2.0
	var ahead := wyrm._to_player().dot(wyrm._charge_dir)
	expect(ahead <= lead + tuning.wyrm_clash_reach + 6.0, "glints as it closes on the player: %s px out" % ahead)
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	wyrm._on_player_sword(head_on(wyrm))
	expect(wyrm.is_stunned(), "a sword hit in the window parries it")
	await physics_frames(2)
	expect(!wyrm._animation_is("slash"), "and the charge is over")

func test_wyvern_red_charge_cannot_be_parried() -> void:
	eager(true)
	autoload("Tuning").wyvern_heavy_charge_chance = 1.0
	var wyvern := await boot_dragon("wyvern")
	await wait_for_glint(wyvern)
	expect(wyvern._unparryable, "the charge glints red")
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	wyvern._on_player_sword(head_on(wyvern))
	expect(!wyvern.is_stunned(), "met head on it isn't parried")
	await physics_frames(2) # The block is resolved at the end of the frame
	expect(!player()._daze_timer.is_stopped(), "the sword is blocked and the player staggered")

func test_wyrm_fireball_flies_straight_and_wyvern_fireball_homes() -> void:
	eager(false)
	for kind: String in ["wyrm", "wyvern"]:
		var dragon := await boot_dragon(kind)
		var fireball: Projectile = null
		for i in 300:
			for child in dragon.room.get_children():
				if child is Projectile:
					fireball = child
			if fireball != null:
				break
			await tree.physics_frame
		expect(fireball != null, "the %s breathes a fireball" % kind)
		if fireball == null:
			continue
		expect(fireball.deflectable, "which can be hit back")
		expect_equal(fireball.shooter, dragon, "and then homes on the %s" % kind)
		if kind == "wyrm":
			expect(fireball.homing_target == null, "a wyrm's flies straight")
		else:
			expect(fireball.homing_target == player(), "a wyvern's homes on the player")

# The way a sword travels that meets `dragon` from the front: against the way it faces.
func head_on(dragon: Wyrm) -> String:
	return {Direction.LEFT: Direction.RIGHT, Direction.RIGHT: Direction.LEFT,
		Direction.UP: Direction.DOWN, Direction.DOWN: Direction.UP}[dragon.direction]
