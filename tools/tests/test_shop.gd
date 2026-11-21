extends "res://tools/tests/test_case.gd"

# The merchant's shop (Merchant, ShopMenu, Game.buy_item). Items are bought for coins into
# the first empty box of the item bar, kept from one floor to the next, and lost on death;
# a run starts with an empty bar. The merchant stands in the start room and can only be
# talked to from close by.

func test_floor_starts_with_an_empty_bar() -> void:
	await boot_floor()
	var game := autoload("Game")
	for slot in 3:
		expect_equal(game.item_in(slot), Items.Kind.NONE, "box %d starts empty" % slot)

func test_buying_fills_the_first_empty_box_and_takes_the_coins() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.coins = 120
	expect_equal(game.buy_item(Items.Kind.METAL_DETECTOR), game.Purchase.BOUGHT, "the detector is bought")
	expect_equal(game.buy_item(Items.Kind.SKELETON_KEY), game.Purchase.BOUGHT, "the key is bought")
	expect_equal(game.item_in(0), Items.Kind.METAL_DETECTOR, "the first purchase goes in the first box")
	expect_equal(game.item_in(1), Items.Kind.SKELETON_KEY, "the next goes in the next box")
	expect_equal(game.coins, 20, "each costs 50 coins")

func test_too_few_coins_buys_nothing() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.coins = Items.price(Items.Kind.SKELETON_KEY) - 1
	expect_equal(game.buy_item(Items.Kind.SKELETON_KEY), game.Purchase.TOO_POOR, "the purchase is refused")
	expect_equal(game.item_in(0), Items.Kind.NONE, "no item is added")
	expect_equal(game.coins, Items.price(Items.Kind.SKELETON_KEY) - 1, "no coins are taken")

func test_full_bar_buys_nothing() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.coins = 1000
	for slot in 3:
		game.buy_item(Items.Kind.SKELETON_KEY)
	expect_equal(game.buy_item(Items.Kind.METAL_DETECTOR), game.Purchase.BAR_FULL, "the purchase is refused")
	expect_equal(game.coins, 850, "only the three that fit were paid for")

func test_items_carry_to_the_next_floor_but_not_past_death() -> void:
	await boot_floor()
	var game := autoload("Game")
	game.coins = 100
	game.buy_item(Items.Kind.SKELETON_KEY)
	game.finish_floor()
	await boot_floor()
	expect_equal(game.item_in(0), Items.Kind.SKELETON_KEY, "the key comes to the next floor")
	expect(game.player_died.is_connected(game.discard_items), "dying discards the items")
	game.discard_items()
	expect_equal(game.item_in(0), Items.Kind.NONE, "discarding empties the bar")
	await boot_floor()
	expect_equal(game.item_in(0), Items.Kind.NONE, "a floor not reached by finishing one starts empty")

func test_merchant_stands_at_the_top_of_the_start_room() -> void:
	await boot_floor()
	var merchant := _merchant()
	expect(merchant != null, "the start room has a merchant")
	if merchant == null:
		return
	var room := merchant.get_parent() as Room
	expect_near(merchant.global_position.x, room.floor_rect.get_center().x + room.global_position.x, 1.0,
		"he stands in the middle")
	expect(merchant.position.y - room.floor_rect.position.y < 30.0, "near the top edge")

func test_merchant_can_only_be_reached_from_close_by() -> void:
	await boot_floor()
	var game := autoload("Game")
	var merchant := _merchant()
	if merchant == null:
		return
	game.player.global_position = merchant.global_position + Vector2(0, 100) - Player.FEET
	expect(!merchant.in_reach(), "out of reach from across the room")
	game.player.global_position = merchant.global_position + Vector2(0, 10) - Player.FEET
	expect(merchant.in_reach(), "in reach just below him")

func test_shop_buys_the_selected_row_and_unpauses_on_close() -> void:
	await boot_floor()
	var game := autoload("Game")
	var merchant := _merchant()
	if merchant == null:
		return
	var shop: ShopMenu = merchant.find_children("*", "ShopMenu", true, false)[0]
	game.coins = 50
	shop.open()
	expect(tree.paused && shop.visible, "opening the shop pauses the game")
	shop.buy_selected()
	expect_equal(game.item_in(0), shop.stock()[0], "the first row's item is bought")
	shop.close()
	expect(!tree.paused && !shop.visible, "closing it unpauses")

func test_shop_guards_against_double_buys() -> void:
	await boot_floor()
	var game := autoload("Game")
	var merchant := _merchant()
	if merchant == null:
		return
	var shop: ShopMenu = merchant.find_children("*", "ShopMenu", true, false)[0]
	game.coins = 1000
	Input.action_press("interact") # Still held from opening the shop
	shop.open()
	await _frames(3)
	Input.action_release("interact")
	await _frames(2)
	expect_equal(game.item_in(0), Items.Kind.NONE, "the press that opened the shop buys nothing")
	await _tap("interact")
	expect_equal(game.item_in(0), Items.Kind.SKELETON_KEY, "a fresh press buys")
	await _tap("interact")
	expect_equal(game.item_in(1), Items.Kind.NONE, "a second press straight after is ignored")
	await wait_real(autoload("Tuning").shop_buy_cooldown + 0.1)
	await _frames(1) # A timer resumes us after this frame's _process has run
	await _tap("interact")
	expect_equal(game.item_in(1), Items.Kind.SKELETON_KEY, "after the cooldown another press buys")
	shop.close()

func test_shop_shows_several_rows_before_scrolling() -> void:
	expect(ShopMenu.VISIBLE_ROWS >= 5, "at least five items fit before the list scrolls")

func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)

func _merchant() -> Merchant:
	var start := (tree.current_scene as Overworld).rooms_by_id[Constants.START_ROOM] as Room
	for child in start.get_children():
		if child is Merchant:
			return child
	return null
