extends "res://tools/tests/test_case.gd"

# The dialogue box (DialogueBox) and the merchant's greeting. A line types out over time; the
# first advance finishes it at once, the next moves on (or closes after the last line). The
# box pauses the game while it's up, and talking to the merchant greets the player before
# his shop opens.

func _box() -> DialogueBox:
	var box := DialogueBox.new()
	tree.root.add_child(box)
	return box

func test_lines_type_out_over_time() -> void:
	var box := _box()
	box.say("Tester", ["Hello there"] as Array[String])
	expect(box.is_typing(), "a fresh line starts typing")
	expect_equal(box.shown_text(), "", "nothing shows at first")
	await wait_real(0.1)
	expect(box.shown_text().length() > 0, "some letters show after a moment")
	await wait_real(1.0)
	expect(!box.is_typing(), "the line finishes on its own")
	expect_equal(box.shown_text(), "Hello there", "all of it shows")
	box.close()
	box.queue_free()

func test_first_advance_finishes_the_line_and_the_next_moves_on() -> void:
	var box := _box()
	var done := [false]
	box.finished.connect(func() -> void: done[0] = true)
	box.say("Tester", ["First line", "Second line"] as Array[String])
	expect(tree.paused, "the game pauses while the box is up")
	box.advance()
	expect(!box.is_typing(), "the first press shows the rest of the line")
	expect_equal(box.shown_text(), "First line", "the whole first line")
	box.advance()
	expect(box.is_typing(), "the second press starts the next line")
	box.advance()
	box.advance()
	expect(!box.visible && done[0], "advancing past the last line closes the box and says so")
	expect(!tree.paused, "and unpauses the game")
	box.queue_free()

func test_long_lines_wrap_between_words() -> void:
	var box := _box()
	box.say("", ["One two three four five six seven eight nine ten eleven twelve"] as Array[String])
	box.advance()
	var shown := box.shown_text()
	expect(!shown.contains("  "), "the line break replaces a space rather than adding one")
	box.close()
	box.queue_free()

func test_merchant_greets_before_the_shop_opens() -> void:
	await boot_floor()
	var start := (tree.current_scene as Overworld).rooms_by_id[Constants.START_ROOM] as Room
	var merchant: Merchant = null
	for child in start.get_children():
		if child is Merchant:
			merchant = child
	if merchant == null:
		expect(false, "the start room has a merchant")
		return
	var box: DialogueBox = merchant.find_children("*", "DialogueBox", true, false)[0]
	var shop: ShopMenu = merchant.find_children("*", "ShopMenu", true, false)[0]
	merchant.talk()
	expect(box.visible && !shop.visible, "talking shows the greeting, not the shop")
	box.advance()
	expect(box.visible && !shop.visible, "skipping the typing keeps the greeting up")
	box.advance()
	expect(!box.visible && shop.visible, "moving it on opens the shop")
	expect(tree.paused, "the game stays paused into the shop")
	shop.close()
