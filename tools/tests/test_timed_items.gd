extends "res://tools/tests/test_case.gd"

# The shop's lucky cat, ram stick, preowned mace and broken watch (Items, ItemEffects). The
# cat raises enemies' drops, the stick lengthens the parry window, the watch stops the level
# timer and hits taking time off it, each for a while; the mace dazes every enemy the next
# swing hits.

const NEW_ITEMS: Array[Items.Kind] = [Items.Kind.LUCKY_CAT, Items.Kind.RAM_STICK,
	Items.Kind.PREOWNED_MACE, Items.Kind.BROKEN_WATCH]

func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

func test_new_items_are_sold_for_50() -> void:
	var stock: Array = ShopMenu.TABS[ShopMenu.ITEMS_TAB].stock
	for kind in NEW_ITEMS:
		expect(stock.has(kind), "%s is in the shop" % Items.INFO[kind].name)
		expect_equal(Items.price(kind), 50, "%s costs 50" % Items.INFO[kind].name)
		expect(Items.ICONS.has(kind), "%s has an icon" % Items.INFO[kind].name)
		expect(!Items.description(kind).contains("%"), "%s's line has its seconds filled in" % Items.INFO[kind].name)

func test_timed_items_last_their_tuned_time() -> void:
	expect_equal(Items.duration(Items.Kind.LUCKY_CAT), 15.0, "a lucky cat lasts 15 s")
	expect_equal(Items.duration(Items.Kind.RAM_STICK), 10.0, "a ram stick lasts 10 s")
	expect_equal(Items.duration(Items.Kind.BROKEN_WATCH), 10.0, "a broken watch lasts 10 s")

func test_lucky_cat_raises_drops_then_wears_off() -> void:
	await boot_floor()
	var tuning := autoload("Tuning")
	expect_equal(ItemEffects.coin_multiplier(), 1.0, "normal coins before")
	expect_equal(ItemEffects.arrow_drop_chance(), tuning.arrow_drop_chance, "normal arrow chance before")
	_use(Items.Kind.LUCKY_CAT)
	expect_equal(ItemEffects.coin_multiplier(), tuning.lucky_cat_coin_multiplier, "more coins under the cat")
	expect_equal(ItemEffects.arrow_drop_chance(), 1.0, "arrows every time under the cat")
	ItemEffects.current().stop(Items.Kind.LUCKY_CAT)
	expect_equal(ItemEffects.coin_multiplier(), 1.0, "normal coins after")

func test_ram_stick_lengthens_the_parry_window() -> void:
	await boot_floor()
	var tuning := autoload("Tuning")
	_use(Items.Kind.RAM_STICK)
	expect_near(ItemEffects.parry_window(), tuning.parry_window * tuning.ram_stick_parry_multiplier,
		0.0001, "the window is longer")
	expect_near(ItemEffects.parry_window(0.1), 0.1 * tuning.ram_stick_parry_multiplier, 0.0001,
		"so is a dragon's breath window")

func test_using_a_timed_item_again_adds_its_time() -> void:
	await boot_floor()
	var effects := ItemEffects.current()
	_use(Items.Kind.RAM_STICK)
	_use(Items.Kind.RAM_STICK)
	expect(effects.time_left(Items.Kind.RAM_STICK) > Items.duration(Items.Kind.RAM_STICK) * 1.5,
		"two sticks last about twice as long")

func test_broken_watch_stops_the_clock_and_hits_take_no_time() -> void:
	await boot_floor()
	var game := autoload("Game")
	var player: Player = game.player
	_go_into_the_cave(player)
	_use(Items.Kind.BROKEN_WATCH)
	expect_equal(game.item_in(0), Items.Kind.NONE, "the watch is used up")
	var countdown := player.level_countdown
	var before := countdown.time_left
	await wait_real(0.3)
	expect_near(countdown.time_left, before, 0.001, "the clock stands still")
	expect(player.take_damage(1.0, "left", true), "the hit lands")
	expect_near(countdown.time_left, before, 0.001, "but takes no time")
	ItemEffects.current().stop(Items.Kind.BROKEN_WATCH)
	await wait_real(0.3)
	expect(countdown.time_left < before - 0.1, "the clock runs again after")

func test_broken_watch_is_kept_where_the_clock_is_still() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.player.current_room = Constants.START_ROOM
	_use(Items.Kind.BROKEN_WATCH)
	expect_equal(game.item_in(0), Items.Kind.BROKEN_WATCH, "the watch stays in its box")
	expect(!ItemEffects.clock_stopped(), "and isn't on")

func test_a_second_mace_is_kept_while_one_is_charged() -> void:
	await boot_floor()
	var game := autoload("Game")
	_use(Items.Kind.PREOWNED_MACE)
	expect(ItemEffects.current().mace_charged, "the mace charges the next swing")
	_use(Items.Kind.PREOWNED_MACE)
	expect_equal(game.item_in(0), Items.Kind.PREOWNED_MACE, "a second mace stays in its box")

func test_mace_swing_dazes_the_enemy_it_hits() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "goblin")
	var room: Room = await boot_design(design)
	var enemy: MeleeEnemy = null
	for child in room.get_children():
		if child is MeleeEnemy:
			enemy = child
	expect(enemy != null, "the room has a goblin")
	if enemy == null:
		return
	var player: Player = autoload("Game").player
	var effects := ItemEffects.current()
	_use(Items.Kind.PREOWNED_MACE)
	player.swing_started_frame = Engine.get_physics_frames()
	effects.on_swing(player.swing_started_frame)
	expect(!effects.mace_charged, "the swing uses the charge")
	var before := enemy.health
	enemy._mace_hit(Direction.LEFT)
	expect(enemy.health < before, "the hit does its damage")
	expect(enemy.is_stunned(), "and dazes the goblin")

# Puts `kind` in the first box and uses it.
func _use(kind: Items.Kind) -> void:
	var game := autoload("Game")
	game.items = [kind] as Array[Items.Kind]
	game.item_slot = 0
	game.use_item()

func _go_into_the_cave(player: Player) -> void:
	for id: int in (tree.current_scene as Overworld).rooms_by_id:
		if !(id in [Constants.START_ROOM, Constants.END_ROOM, Constants.BOSS_ROOM]):
			player.current_room = id
			return
