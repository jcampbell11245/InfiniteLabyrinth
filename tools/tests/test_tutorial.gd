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

# The tutorial's script (Tutorial), found under the Overworld.
func _script(world: Overworld) -> Tutorial:
	for child in world.get_children():
		if child is Tutorial:
			return child
	return null

# Moves every line of an open dialogue box on, finishing each first.
func _dismiss(box: DialogueBox) -> void:
	for i in 20:
		if !box.visible:
			return
		box.advance()
		await tree.process_frame

func test_merchant_unlocks_the_start_room() -> void:
	var world := await _boot_tutorial()
	var start: Room = world.rooms_by_id[Constants.START_ROOM]
	expect(start.has_locked_doors(), "the start room's door starts locked")
	var locks: TileMap = start.get_node("Locks")
	var right: Vector2i = start.door_cells[Room.Door.RIGHT]
	expect_equal(locks.get_cell_source_id(0, right), 2, "with the lever lock")
	var merchant: Merchant = start.get_node("Merchant")
	merchant.talk()
	var box: DialogueBox = merchant._dialogue
	expect(box.visible, "he talks")
	expect_equal(box._lines, Tutorial.WELCOME, "he welcomes the player")
	expect(start.has_locked_doors(), "still locked while he talks")
	await _dismiss(box)
	expect(!merchant._shop.visible, "no shop opens")
	expect(!start.has_locked_doors(), "the door opens once he's done")
	expect_equal(locks.get_cell_source_id(0, right), 8, "the lock is drawn open")
	_leave_tutorial()

func test_merchant_speaks_in_the_first_room() -> void:
	var world := await _boot_tutorial()
	var tutorial := _script(world)
	expect(tutorial != null, "the tutorial runs its script")
	expect(world.rooms_by_id[0].is_key_room(), "the chest room shows yellow on the minimap")
	var player: Player = autoload("Game").player
	player.current_room = 0
	autoload("Game").room_entered.emit(0)
	await tree.process_frame
	await tree.process_frame
	var box: DialogueBox = tutorial._dialogue
	expect(box.visible, "he speaks up on entering")
	expect_equal(box._lines, Tutorial.MINIMAP, "about the minimap")
	await _dismiss(box)
	autoload("Game").room_entered.emit(0)
	await tree.process_frame
	await tree.process_frame
	expect(!tutorial.is_speaking(), "only the first time")

	var room: Room = world.rooms_by_id[0]
	var chest: Node = room.get_node("Chest")
	chest._on_area_2d_area_entered(player.get_node("HitboxPivot/Hitbox"))
	await tree.process_frame
	var hourglasses := room.get_children().filter(
			func(child: Node) -> bool: return child.get_script() == preload("res://src/effects/TimePickup.gd"))
	expect(hourglasses.is_empty(), "the chest holds no hourglass")
	await wait_real(Tutorial.KEY_LINE_DELAY + 0.3)
	expect(box.visible, "he speaks once the chest is open")
	expect_equal(box._lines, Tutorial.KEY, "about the key")
	await _dismiss(box)
	_leave_tutorial()
