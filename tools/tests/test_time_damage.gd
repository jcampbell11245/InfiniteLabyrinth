extends "res://tools/tests/test_case.gd"

# There's no health: damage takes time off the level timer (Player.lose_time), and a hit
# worth more than the time left ends the run after the timer's countdown (LevelTimer).

func test_hit_takes_seconds_per_damage() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	var tuning := autoload("Tuning")
	var before := player.level_countdown.time_left
	expect(player.take_damage(1.0, "left", true), "the hit lands")
	expect_near(before - player.level_countdown.time_left, tuning.seconds_per_damage, 0.2,
		"seconds taken by 1 damage")

func test_more_damage_takes_more_time() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	var tuning := autoload("Tuning")
	var before := player.level_countdown.time_left
	player.take_damage(2.5, "left", true)
	expect_near(before - player.level_countdown.time_left, 2.5 * tuning.seconds_per_damage, 0.2,
		"seconds taken by 2.5 damage")

func test_invincibility_after_a_hit() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	player.take_damage(1.0, "left", true)
	var after_first := player.level_countdown.time_left
	expect(!player.take_damage(1.0, "left", true), "a second hit straight away doesn't land")
	expect_near(player.level_countdown.time_left, after_first, 0.2, "no time taken by it")

func test_god_mode_takes_no_time() -> void:
	await boot_floor()
	var player: Player = autoload("Game").player
	autoload("Tuning").god_mode = true
	var before := player.level_countdown.time_left
	player.take_damage(1.0, "left", true)
	expect_near(player.level_countdown.time_left, before, 0.2, "time left in god mode")

func test_lethal_hit_counts_down_then_ends_the_run() -> void:
	await boot_floor()
	var game := autoload("Game")
	var player: Player = game.player
	var died := [false]
	game.player_died.connect(func() -> void: died[0] = true)
	player.level_countdown.start(5.0)
	player.take_damage(1.0, "left", true)
	expect(!died[0], "the run doesn't end on the hit itself")
	expect(Engine.time_scale < 0.5, "slow motion while the timer counts down")
	expect(!player.take_damage(5.0, "left", true), "no more hits land while dying")
	await wait_real(Player.FATAL_FALLBACK + 0.5)
	expect(died[0], "the run ends after the countdown")
	expect_near(Engine.time_scale, autoload("Tuning").game_speed, 0.01, "normal speed for the game over")
