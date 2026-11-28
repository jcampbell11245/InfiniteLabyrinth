extends "res://tools/tests/test_case.gd"

# The tutorial (F3 on the title screen): the start room, Overworld.TUTORIAL_ROOMS rooms in a
# line on the middle row, then the end room; no timer, no boss door, a one-key gate.

func _boot_tutorial() -> Overworld:
	Overworld.tutorial = true
	await boot_floor()
	return tree.current_scene as Overworld

func _leave_tutorial() -> void:
	Overworld.tutorial = false # So later tests get real floors

func test_rooms_lie_in_one_line() -> void:
	var world := await _boot_tutorial()
	var ids: Array = world.rooms_by_id.keys()
	expect_equal(ids.size(), Overworld.TUTORIAL_ROOMS + 2, "start room, tutorial rooms and end room")
	expect(!world.rooms_by_id.has(Constants.BOSS_ROOM), "no boss room")
	var line: Array[Room] = [world.rooms_by_id[Constants.START_ROOM]]
	for i in range(Overworld.TUTORIAL_ROOMS):
		line.append(world.rooms_by_id[i])
		expect_equal(world.rooms_by_id[i].scene_file_path, Overworld.tutorial_room(i), "room %d's scene" % i)
	line.append(world.rooms_by_id[Constants.END_ROOM])
	for i in range(line.size()):
		expect_equal(line[i].position, world.grid_position(WorldGenerator.MIDDLE_ROW, i), "room %d of the line" % i)
		expect(!line[i].doors[Room.Door.TOP] && !line[i].doors[Room.Door.BOTTOM], "room %d's top and bottom doors are shut" % i)
		expect_equal(line[i].doors[Room.Door.LEFT], i != 0, "room %d's left door" % i)
		expect_equal(line[i].doors[Room.Door.RIGHT], i != line.size() - 1, "room %d's right door" % i)
	var start: Room = line[0]
	for node_name in Overworld.BOSS_DOOR_NODES:
		expect(!start.has_node(node_name), "the start room has no %s" % node_name)
	expect(start.has_node("Merchant"), "the merchant is still in the start room")
	_leave_tutorial()

func test_no_timer() -> void:
	var world := await _boot_tutorial()
	var player: Player = autoload("Game").player
	player.current_room = 0 # A cave room, where a floor's clock would run
	await wait_real(0.2)
	expect(player.level_countdown.is_stopped(), "the level countdown never starts")
	var before := player.position
	player.lose_time(1000.0)
	expect(!player._dying, "a hit can't run the time out")
	expect(player.position == before, "nothing happened to the player")
	expect(world != null, "the tutorial built")
	_leave_tutorial()

func test_one_key_opens_the_end_room() -> void:
	await _boot_tutorial()
	var game := autoload("Game")
	var tuning := autoload("Tuning")
	expect_equal(Room.keys_to_finish(), tuning.tutorial_keys_to_finish, "the tutorial's gate wants its own count")
	expect_equal(tuning.tutorial_keys_to_finish, 1, "one key by default")
	var end := game.room_by_id(Constants.END_ROOM) as Room
	expect(end.get_node_or_null("KeyGate") != null, "the gate starts shut")
	game.keys = 0
	game.add_keys(1)
	await tree.process_frame
	await tree.process_frame
	expect(end.get_node_or_null("KeyGate") == null, "one key opens the gate")
	_leave_tutorial()

func test_exit_goes_to_the_title() -> void:
	var world := await _boot_tutorial()
	var save := autoload("SaveData")
	var floor_before: int = save.floor_number
	world.rooms_by_id[Constants.END_ROOM]._on_next_floor_area_entered(null)
	for i in 10:
		await tree.process_frame
	expect_equal(tree.current_scene.scene_file_path, Overworld.TITLE_SCREEN, "the exit leads to the title screen")
	expect(!Overworld.tutorial, "the title screen ends the tutorial")
	expect_equal(save.floor_number, floor_before, "the save's floor is untouched")
	_leave_tutorial()
