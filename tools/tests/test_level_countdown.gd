extends "res://tools/tests/test_case.gd"

# The floor's countdown (LevelCountdown) only runs in the cave: it holds still while the
# player is in the start room or the end room.

func test_clock_stands_still_in_start_and_end_rooms() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	var countdown: Timer = player.level_countdown
	for room: int in [Constants.START_ROOM, Constants.END_ROOM]:
		player.current_room = room
		var before := countdown.time_left
		await wait_real(0.3)
		expect_near(countdown.time_left, before, 0.001, "the clock stands still in room %d" % room)

func test_clock_runs_in_the_cave() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	var countdown: Timer = player.level_countdown
	for id: int in (tree.current_scene as Overworld).rooms_by_id:
		if !(id in [Constants.START_ROOM, Constants.END_ROOM, Constants.BOSS_ROOM]):
			player.current_room = id
			break
	var before := countdown.time_left
	await wait_real(0.3)
	expect(countdown.time_left < before - 0.1, "the clock counts down in a cave room")
