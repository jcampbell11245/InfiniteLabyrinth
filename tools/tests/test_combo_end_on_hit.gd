extends "res://tools/tests/test_case.gd"

# Enemy combos end when a hit lands on the player (Tuning.combos_end_on_hit, Enemy.landed_hit):
# a melee enemy's turn has no more swings, and no double attack follows.

func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

func goblin() -> MeleeEnemy:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "goblin")
	var room: Room = await boot_design(design)
	for child in room.get_children():
		if child is MeleeEnemy:
			return child
	return null

func test_a_hit_ends_a_melee_turn() -> void:
	var enemy := await goblin()
	enemy._swings_left = 3
	enemy._follow_up_ready = true
	enemy.landed_hit()
	expect_equal(enemy._swings_left, 0, "no more swings this turn")
	expect(!enemy._follow_up_ready, "and no double attack")

func test_switched_off_a_hit_ends_nothing() -> void:
	autoload("Tuning").combos_end_on_hit = false
	var enemy := await goblin()
	enemy._swings_left = 3
	enemy.landed_hit()
	expect_equal(enemy._swings_left, 3, "its turn goes on")
