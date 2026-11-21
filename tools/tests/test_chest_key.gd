extends "res://tools/tests/test_case.gd"

# Opening a key chest releases a floating key: it doesn't grant the key at once, but adds
# one and extends the level timer when it reaches the player.

func test_chest_key_floats_then_grants_key_and_time() -> void:
	await boot_floor()
	var game := autoload("Game")
	var tuning := autoload("Tuning")
	var player: Player = game.player
	var countdown: Timer = player.level_countdown

	# Give the player a known timer value and keep it from draining during the test.
	countdown.start(60.0)
	tuning.freeze_timer = true

	var chest: Node2D = load("res://src/objects/Chest.tscn").instantiate()
	player.get_parent().add_child(chest)
	chest.global_position = player.global_position + Vector2(40, 0)
	await tree.process_frame

	var keys_before: int = game.keys
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	chest._on_area_2d_area_entered(hitbox)
	hitbox.free()

	expect_equal(game.keys, keys_before, "key not granted immediately when chest opens")
	expect_near(countdown.time_left, 60.0, 0.2, "timer unchanged before key is collected")

	# Wait for the key to float over and be collected.
	for i in 240:
		await tree.process_frame
		if game.keys == keys_before + 1:
			break

	expect_equal(game.keys, keys_before + 1, "key granted after pickup reaches the player")
	expect_near(countdown.time_left, 60.0 + tuning.key_time_bonus, 0.3,
		"time bonus added when key is collected")
