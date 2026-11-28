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
	var box: DialogueBox = tutorial._dialogue
	await wait_real(Tutorial.ROOM_LINE_DELAY + 0.2)
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

# Waits up to `seconds` of real time for `done` to return true; false if it never does.
func _wait_for(done: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await tree.process_frame
	return done.call()

func test_parry_lesson() -> void:
	var world := await _boot_tutorial()
	var game := autoload("Game")
	var tutorial := _script(world)
	var box: DialogueBox = tutorial._dialogue
	var room: Room = world.rooms_by_id[Tutorial.PARRY_ROOM]
	var goblin: TutorialGoblin = room.get_node("Goblin")
	var player: Player = game.player
	var full_health := goblin.health
	player.position = room.position + room.centre + Vector2(-60, 0)
	player.current_room = Tutorial.PARRY_ROOM
	game.room_entered.emit(Tutorial.PARRY_ROOM)
	expect(await _wait_for(func() -> bool: return box.visible, 2.0), "he speaks on entering")
	expect(box._lines[0].contains(Tutorial.attack_button()), "naming the attack button")
	expect(room.has_locked_doors(), "the room is locked until the goblin is beaten")
	await _dismiss(box)

	# Arrows and swings do nothing to it yet; the first block brings the next line.
	goblin.take_damage(Direction.RIGHT, 5.0)
	expect_equal(goblin.health, full_health, "an arrow does it no harm")
	expect(await _wait_for(func() -> bool: return box.visible, 2.0), "a block brings his next line")
	expect_equal(box._lines, Tutorial.NOT_LIKE_THAT, "telling the player to parry")
	expect_equal(goblin.stage, TutorialGoblin.Stage.GUARDING, "it waits for him to finish")
	await _dismiss(box)
	expect_equal(goblin.stage, TutorialGoblin.Stage.ATTACKING, "then it attacks")

	# It comes and swings; its star freezes the game under a spotlight.
	var struck := [false]
	var watch := func() -> bool:
		if !goblin.hitbox.disabled:
			struck[0] = true
		return tree.paused && tutorial._spotlight != null
	expect(await _wait_for(watch, 6.0), "its star freezes the game under a spotlight")
	expect_equal(box._lines, Tutorial.STRIKE_NOW, "and he says to strike")
	expect(is_instance_valid(goblin._held_star), "its star stays on its blade")
	var press := InputEventAction.new()
	press.action = "melee_attack"
	press.pressed = true
	tutorial._input(press)
	expect(!tree.paused, "pressing attack lets the game go")
	expect(player._queued_swing, "and the press swings once the sword is ready")
	player._queued_swing = false # The test swings by hand below
	expect(!box.visible, "and moves the line on")

	# However long the player waits, the swing doesn't come.
	await wait_real(1.5)
	expect(!struck[0] && goblin.hitbox.disabled, "its swing never lands")
	expect(goblin._animation_is("slash"), "it's held in its windup")
	player.swing_started_at = Time.get_ticks_msec()
	player.swing_started_frame = Engine.get_physics_frames()
	goblin._on_player_sword(Direction.RIGHT)
	expect_equal(goblin.stage, TutorialGoblin.Stage.DAZED, "a swing now parries it")
	expect(await _wait_for(func() -> bool: return box.visible, 2.0), "he speaks once it's dazed")
	expect_equal(box._lines, Tutorial.DAZED, "telling the player to finish it")
	await _dismiss(box)
	await wait_real(2.0)
	expect(goblin.is_stunned(), "the daze doesn't run down")

	for i in 10:
		if !is_instance_valid(goblin) || goblin.health <= 0:
			break
		goblin.invincibility_cooldown.stop()
		goblin.take_damage(Direction.RIGHT, 1.0)
		await tree.process_frame
	await tree.process_frame
	expect(!room.has_locked_doors(), "beating it opens the room")
	_leave_tutorial()
