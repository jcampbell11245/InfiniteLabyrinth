extends "res://tools/tests/test_case.gd"

# The item bar's highlight moves one box at a time with item_previous / item_next and wraps
# round at either end; using an item reports the highlighted box. Shrinking the bar from
# the debug menu pulls the highlight back onto a box that still exists.

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

func test_use_item_reports_highlighted_box() -> void:
	var game := autoload("Game")
	autoload("Tuning").set_value("item_slots", 3)
	game.item_slot = 2
	var used: Array[int] = []
	var record := func(slot: int) -> void: used.append(slot)
	game.item_used.connect(record)
	game.use_item()
	game.item_used.disconnect(record)
	expect_equal(used, [2] as Array[int], "using an item reports the highlighted box")

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
