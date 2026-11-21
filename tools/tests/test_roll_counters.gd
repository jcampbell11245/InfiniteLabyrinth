extends "res://tools/tests/test_case.gd"

# Rolling through an unparryable (red) attack and hitting the enemy from behind dazes it like
# a parry, with no damage (Enemy._dazed_from_behind): during the attack, and while it's still
# stuck recovering from it (a knight's end lag, a wyvern hanging in the air).

const ENEMY_AT := Vector2i(6, 6)

func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

func player() -> Player:
	return autoload("Game").player

# A room with one `kind` of enemy in it, facing the player, and the enemy.
func boot_enemy(kind: String) -> Enemy:
	var design := RoomDesign.new()
	design.set_object(ENEMY_AT, kind)
	design.set_facing(ENEMY_AT, Direction.LEFT)
	design.set_radius(ENEMY_AT, RoomDesign.RADIUS_MAX)
	var room: Room = await boot_design(design)
	for child in room.get_children():
		if child is Enemy:
			return child
	return null

# A sword hit from behind: travelling the way the enemy faces.
func hit_from_behind(enemy: Enemy) -> void:
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	enemy._on_player_sword(enemy.direction)

# A knight's red swing, winding up and waiting for its glint.
func red_swing(knight: MeleeEnemy) -> void:
	autoload("Tuning").unparryable_chance = 1.0
	knight._start_swing(true)
	for i in 300:
		if knight._twinkled_at >= 0:
			return
		await tree.physics_frame

func test_hit_from_behind_during_a_red_swing_dazes() -> void:
	var knight: MeleeEnemy = await boot_enemy("knight")
	await red_swing(knight)
	expect(knight._unparryable, "a red swing")
	var health := knight.health
	hit_from_behind(knight)
	await tree.physics_frame
	expect(knight.is_stunned(), "a hit from behind dazes it")
	expect_equal(knight.health, health, "with no damage")

func test_hit_from_behind_in_end_lag_dazes() -> void:
	var knight: MeleeEnemy = await boot_enemy("knight")
	player().invincibility_cooldown.start(100.0)
	await red_swing(knight)
	for i in 300:
		if knight.in_end_lag():
			break
		await tree.physics_frame
	expect(knight.in_end_lag(), "frozen after the red swing")
	var health := knight.health
	hit_from_behind(knight)
	await tree.physics_frame
	expect(knight.is_stunned(), "a hit from behind dazes it")
	expect(!knight.in_end_lag(), "out of its end lag")
	expect_equal(knight.health, health, "with no damage")

func test_hit_from_the_front_in_end_lag_still_hurts() -> void:
	var knight: MeleeEnemy = await boot_enemy("knight")
	player().invincibility_cooldown.start(100.0)
	await red_swing(knight)
	for i in 300:
		if knight.in_end_lag():
			break
		await tree.physics_frame
	var health := knight.health
	player().swing_started_at = Time.get_ticks_msec()
	player().swing_started_frame = Engine.get_physics_frames()
	knight._on_player_sword({Direction.LEFT: Direction.RIGHT, Direction.RIGHT: Direction.LEFT,
		Direction.UP: Direction.DOWN, Direction.DOWN: Direction.UP}[knight.direction])
	await tree.physics_frame
	expect(knight.health < health, "an ordinary hit")
	expect(!knight.is_stunned(), "with no daze")

func test_hit_from_behind_on_a_hanging_wyvern_dazes() -> void:
	var tuning := autoload("Tuning")
	tuning.wyrm_attack_cooldown_min = 1000.0
	tuning.wyrm_attack_cooldown_max = 1000.0
	var wyvern: Wyrm = await boot_enemy("wyvern")
	wyvern._recover_rooted = true # Hanging open after a red charge
	wyvern._recover.start(1.0)
	var health := wyvern.health
	hit_from_behind(wyvern)
	await tree.physics_frame
	expect(wyvern.is_stunned(), "a hit from behind dazes it")
	expect_equal(wyvern.health, health, "with no damage")
