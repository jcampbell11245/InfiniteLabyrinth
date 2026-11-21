extends "res://tools/tests/test_case.gd"

# The item bar (ItemBar) and its items (Items). The highlight moves one box at a time with
# item_previous / item_next and wraps round at either end; shrinking the bar from the debug
# menu pulls it back onto a box that still exists. Using an item only uses it up when it
# did something: a skeleton key needs a locked door in the player's room, a metal detector
# a key room the minimap doesn't show yet.

func test_highlight_wraps_round_both_ends() -> void:
	var game := autoload("Game")
	var tuning := autoload("Tuning")
	tuning.set_value("item_slots", 3)
	game.item_slot = 0
	game.cycle_item(-1)
	expect_equal(game.item_slot, 2, "going left from the first box lands on the last")
	game.cycle_item(1)
	expect_equal(game.item_slot, 0, "going right from the last box lands on the first")
	game.cycle_item(1)
	expect_equal(game.item_slot, 1, "going right moves one box")

func test_shrinking_bar_keeps_highlight_on_a_box() -> void:
	await boot_floor()
	var game := autoload("Game")
	var tuning := autoload("Tuning")
	tuning.set_value("item_slots", 3)
	game.item_slot = 2
	tuning.set_value("item_slots", 2)
	expect_equal(game.item_slot, 0, "the highlight wraps onto a box that still exists")
	tuning.reset("item_slots")

func test_item_actions_are_bound() -> void:
	for action: String in ["item_previous", "item_next", "use_item"]:
		expect(InputMap.has_action(action) && !InputMap.action_get_events(action).is_empty(),
			"%s has bindings" % action)

func test_floor_starts_with_the_starting_items() -> void:
	await boot_floor()
	var game := autoload("Game")
	expect_equal(game.item_in(0), Items.Kind.SKELETON_KEY, "the first box holds a skeleton key")
	expect_equal(game.item_in(1), Items.Kind.METAL_DETECTOR, "the second box holds a metal detector")
	expect_equal(game.item_in(2), Items.Kind.NONE, "the third box is empty")

func test_empty_box_is_refused() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.items = [Items.Kind.NONE] as Array[Items.Kind]
	game.item_slot = 0
	var refused := _record(game.item_refused)
	game.use_item()
	expect_equal(refused, [0], "using an empty box is refused")
	_stop_recording()

func test_skeleton_key_opens_a_locked_room() -> void:
	await boot_floor()
	var game := autoload("Game")
	var room := _locked_room()
	expect(room != null, "the floor has a room that locks")
	if room == null:
		return
	game.player.current_room = room.room_id
	game.room_entered.emit(room.room_id)
	expect(room.has_locked_doors(), "entering the room locks its doors")
	_hold(Items.Kind.SKELETON_KEY)
	var used := _record(game.item_used)
	game.use_item()
	expect(!room.has_locked_doors() && room.is_cleared(), "the key opens the doors")
	expect_equal(game.item_in(0), Items.Kind.NONE, "the key is used up")
	expect_equal(used.size(), 1, "using it is reported")
	_stop_recording()

func test_skeleton_key_is_kept_without_a_locked_door() -> void:
	await boot_floor()
	var game := autoload("Game")
	expect(!game.room_by_id(Constants.START_ROOM).has_locked_doors(), "the start room never locks")
	_hold(Items.Kind.SKELETON_KEY)
	var refused := _record(game.item_refused)
	game.use_item()
	expect_equal(game.item_in(0), Items.Kind.SKELETON_KEY, "the key stays in its box")
	expect_equal(refused, [0], "using it is refused")
	_stop_recording()

func test_metal_detector_marks_one_key_room() -> void:
	await boot_floor()
	var game := autoload("Game")
	var before := Items.unmarked_key_rooms().size()
	expect(before > 0, "the floor has key rooms to find")
	var marked := _record(game.room_marked)
	_hold(Items.Kind.METAL_DETECTOR)
	game.use_item()
	expect_equal(Items.unmarked_key_rooms().size(), before - 1, "one key room is marked")
	expect_equal(marked.size(), 1, "the minimap is told which")
	if marked.size() == 1:
		expect(game.room_by_id(marked[0]).is_key_room(), "the marked room is a key room")
	expect_equal(game.item_in(0), Items.Kind.NONE, "the detector is used up")
	_stop_recording()

func test_metal_detector_is_kept_when_every_key_room_is_marked() -> void:
	await boot_floor()
	var game := autoload("Game")
	for room: Room in Items.unmarked_key_rooms():
		room.marked = true
	_hold(Items.Kind.METAL_DETECTOR)
	var refused := _record(game.item_refused)
	game.use_item()
	expect_equal(game.item_in(0), Items.Kind.METAL_DETECTOR, "the detector stays in its box")
	expect_equal(refused, [0], "using it is refused")

# Puts `kind` alone in the first box and highlights it.
	_stop_recording()

func _hold(kind: Items.Kind) -> void:
	var game := autoload("Game")
	game.items = [kind] as Array[Items.Kind]
	game.item_slot = 0

var _recording: Array[Array] = [] # [signal, callable] pairs to disconnect after the test

# Collects the first argument of every emission of `sig`, until _stop_recording().
func _record(sig: Signal) -> Array:
	var seen := []
	var collect := func(...args: Array) -> void: seen.append(args[0])
	sig.connect(collect)
	_recording.append([sig, collect])
	return seen

# The signals are on the Game autoload, which outlives the test.
func _stop_recording() -> void:
	for pair in _recording:
		(pair[0] as Signal).disconnect(pair[1])
	_recording.clear()

# A room on this floor that locks its doors until cleared and hasn't been cleared.
func _locked_room() -> Room:
	for room: Room in (tree.current_scene as Overworld).rooms_by_id.values():
		if room.completion_criteria != "none" && room.get_node_or_null("Locks") != null \
				&& !room.is_cleared() && room.doors.has(true):
			return room
	return null
