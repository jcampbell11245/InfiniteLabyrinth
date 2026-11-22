extends "res://tools/tests/test_case.gd"

# Servers (Server.gd, ServerBuff.gd): each test plays a one-room design with a server and a
# goblin or two, as the room creator's play-test does, with the enemies frozen so they stay
# where they were put. Boosts are reread by calling refresh_buffs, which a frozen enemy's
# watcher doesn't do by itself.

const SERVER_AT := Vector2i(6, 6)
const NEAR := Vector2i(7, 6) # One cell from the server: inside its default circle
const FAR := Vector2i(12, 0) # Out of the default 5-cell circle

func boot_design(design: RoomDesign) -> Room:
	autoload("Tuning").freeze_enemies = true
	autoload("Tuning").floor_server_chance_max = 0.0 # No server turns gold unless a test says so
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

# The design's enemies once it's playing: the server, and goblins by floor cell.
func find_server(room: Room) -> Server:
	for child in room.get_children():
		if child is Server:
			return child
	return null

func goblin_at(room: Room, index: Vector2i) -> Enemy:
	var at := RoomDesign.object_origin("goblin", index)
	for child in room.get_children():
		if child is Enemy && !(child is Server) && (child as Enemy).position.distance_to(at) < 1.0:
			return child
	return null

# A room with a server boosting `buff` and goblins near it and far from it.
func boot_server(buff: String, whole_room := false) -> Room:
	var design := RoomDesign.new()
	design.set_object(SERVER_AT, "server")
	design.set_server_buff(SERVER_AT, buff)
	design.set_server_whole_room(SERVER_AT, whole_room)
	design.set_object(NEAR, "goblin")
	design.set_object(FAR, "goblin")
	design.clear_by = "enemies"
	return await boot_design(design)

func refresh(room: Room) -> void:
	for child in room.get_children():
		if child is Enemy:
			(child as Enemy).refresh_buffs()

# Hits `enemy` with the sword `times` times, never a crit, clearing its invincibility between.
func sword_hits(enemy: Enemy, times: int) -> void:
	enemy.critical_chance = 0
	for i in times:
		enemy.invincibility_cooldown.stop()
		enemy.take_damage(Direction.RIGHT, autoload("Game").player.sword_damage())

func test_breaks_in_three_sword_hits_and_doesnt_count_towards_clearing() -> void:
	var room := await boot_server("attack")
	var server := find_server(room)
	expect(server != null, "the server is in the room")
	expect_equal(room.enemy_count, 2, "only the two goblins count towards clearing")
	sword_hits(server, 2)
	expect(server.health > 0, "two hits leave it standing")
	sword_hits(server, 1)
	expect(server.health <= 0 && server.is_queued_for_deletion(), "the third hit breaks it")
	expect_equal(room.enemy_count, 2, "breaking it clears nothing")

func test_one_swing_hits_it_once() -> void:
	var room := await boot_server("attack")
	var server := find_server(room)
	var player: Player = autoload("Game").player
	server.critical_chance = 0
	player.swing_started_frame = 1000
	server._on_player_sword(Direction.RIGHT)
	var after_one := server.health
	server.invincibility_cooldown.stop() # As if the sword were still out when it wore off
	server._on_player_sword(Direction.RIGHT)
	expect_equal(server.health, after_one, "the same swing doesn't hit it again")
	player.swing_started_frame = 1030
	server.invincibility_cooldown.stop()
	server._on_player_sword(Direction.RIGHT)
	expect(server.health < after_one, "the next swing does")

func test_one_spin_hits_it_once() -> void:
	var room := await boot_server("attack")
	var server := find_server(room)
	var player: Player = autoload("Game").player
	server.critical_chance = 0
	player.spin_started_frame = 1000
	server.spin_hit()
	var after_one := server.health
	server.invincibility_cooldown.stop() # The spin outlasts its invincibility
	server.spin_hit()
	expect_equal(server.health, after_one, "the same spin doesn't hit it again")
	expect(after_one > 0, "and it's still standing after one spin")

func test_crit_breaks_it_at_once() -> void:
	var room := await boot_server("attack")
	var server := find_server(room)
	server.critical_chance = autoload("Tuning").crit_roll_max + 1 # Always crits
	server.take_damage(Direction.RIGHT, 1.0)
	expect(server.is_queued_for_deletion(), "a crit breaks it in one hit")

func test_attack_boost_inside_its_circle_only() -> void:
	var room := await boot_server("attack")
	refresh(room)
	var near := goblin_at(room, NEAR)
	var far := goblin_at(room, FAR)
	var base: float = near._base.damage * autoload("Tuning").enemy_damage_multiplier
	expect_equal(near.buff_strength(ServerBuff.Kind.ATTACK), 1.0, "the goblin in the circle has the full boost")
	expect_near(near.damage, base * autoload("Tuning").server_attack_multiplier, 0.001, "its damage is boosted")
	expect_equal(far.buff_strength(ServerBuff.Kind.ATTACK), 0.0, "the goblin outside it has none")
	expect_near(far.damage, base, 0.001, "its damage is normal")
	expect_equal(near.buff_strength(ServerBuff.Kind.DEFENSE), 0.0, "it gives no other boost")
	expect_equal(find_server(room).buff_strength(ServerBuff.Kind.ATTACK), 0.0, "it doesn't boost itself")

func test_whole_room_reaches_every_enemy() -> void:
	var room := await boot_server("attack", true)
	refresh(room)
	expect_equal(goblin_at(room, FAR).buff_strength(ServerBuff.Kind.ATTACK), 1.0, "the far goblin is boosted")

func test_boost_ends_the_moment_it_breaks() -> void:
	var room := await boot_server("attack")
	refresh(room)
	var near := goblin_at(room, NEAR)
	var server := find_server(room)
	sword_hits(server, 3)
	refresh(room)
	expect_equal(near.buff_strength(ServerBuff.Kind.ATTACK), 0.0, "the boost is gone")
	expect_near(near.damage, near._base.damage * autoload("Tuning").enemy_damage_multiplier, 0.001,
		"damage is back to normal")

func test_boost_bar_stays_full() -> void:
	var room := await boot_server("speed")
	refresh(room)
	var near := goblin_at(room, NEAR)
	await wait_real(0.5)
	refresh(room)
	expect_equal(near.buff_strength(ServerBuff.Kind.SPEED), 1.0, "the bar hasn't run down")

func test_defense_boost_cuts_damage_taken() -> void:
	var room := await boot_server("defense")
	refresh(room)
	var near := goblin_at(room, NEAR)
	var before := near.health
	sword_hits(near, 1)
	expect_near(before - near.health,
		autoload("Game").player.sword_damage() * autoload("Tuning").server_defense_multiplier, 0.001,
		"a sword hit does the defense multiplier's share")

func test_speed_boost_speeds_walking_and_attacking() -> void:
	var room := await boot_server("speed")
	refresh(room)
	var near := goblin_at(room, NEAR)
	var boost: float = autoload("Tuning").server_speed_multiplier
	expect_near(near.speed, near._base.speed * autoload("Tuning").enemy_speed_multiplier * boost, 0.001, "walks faster")
	expect_near(near.ground_factor(), boost, 0.001, "attacks (and animates) faster")

func test_floor_server_gives_half_everywhere_else() -> void:
	var room := await boot_server("attack")
	var server := find_server(room)
	server.make_floor_server()
	refresh(room)
	var far := goblin_at(room, FAR)
	expect_equal(far.buff_strength(ServerBuff.Kind.ATTACK), autoload("Tuning").floor_server_strength,
		"outside its circle it gives the floor share")
	expect_near(far.buff_multiplier(ServerBuff.Kind.ATTACK), 1.25, 0.001, "half of the 1.5x boost")
	expect_equal(goblin_at(room, NEAR).buff_strength(ServerBuff.Kind.ATTACK), 1.0,
		"inside it, the full boost (the stronger one wins)")
	sword_hits(server, 3)
	refresh(room)
	expect_equal(far.buff_strength(ServerBuff.Kind.ATTACK), 0.0, "breaking it ends the floor boost")

func test_floor_server_chance_climbs_to_its_cap() -> void:
	expect_near(ServerBuff.floor_server_chance(1), 0.05, 0.0001, "5% on floor 1")
	expect_near(ServerBuff.floor_server_chance(2), 0.10, 0.0001, "10% on floor 2")
	expect_near(ServerBuff.floor_server_chance(8), 0.40, 0.0001, "40% on floor 8")
	expect_near(ServerBuff.floor_server_chance(20), 0.40, 0.0001, "capped at 40%")

# The floor chance is rolled for each server on its own, not once for the whole floor.
func test_each_server_rolls_its_own_floor_chance() -> void:
	var design := RoomDesign.new()
	for x in 8:
		design.set_object(Vector2i(x + 2, 2), "server")
	var room := await boot_design(design)
	var tuning := autoload("Tuning")
	tuning.floor_server_chance_first = 0.5
	tuning.floor_server_chance_max = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gold := ServerBuff.roll_floor_servers(room.get_tree(), 1, rng)
	expect(gold.size() > 0 && gold.size() < 8,
		"some of the eight servers turn gold and some don't (%d did)" % gold.size())
	for server in gold:
		expect(server.floor_server, "each one rolled gold is a floor server")

# The banner names each boost once, and wraps rather than running off the screen.
func test_banner_names_the_boosts_and_wraps() -> void:
	var design := RoomDesign.new()
	var buffs := ["attack", "defense", "attack", "random_swap"]
	for x in buffs.size():
		design.set_object(Vector2i(x * 3 + 1, 2), "server")
		design.set_server_buff(Vector2i(x * 3 + 1, 2), buffs[x])
	var room := await boot_design(design)
	var gold: Array[Server] = []
	for child in room.get_children():
		if child is Server:
			gold.append(child)
	expect_equal(FloorBanner.describe(gold),
		"4 premium servers are boosting enemy attack and defense across this floor. "
		+ "Some keep changing their boosts. Destroy them to end it.", "each boost named once")
	expect_equal(FloorBanner.describe(gold.slice(0, 1)),
		"A premium server is boosting enemy attack across this floor. Destroy it to end it.", "one server")
	var banner := FloorBanner.show_for(room, gold)
	for i in 2:
		await room.get_tree().process_frame
	var panel := banner.get_child(0).get_child(0) as Control
	expect(panel.size.x < 1920, "the banner fits across the screen (%d px)" % panel.size.x)
	banner.queue_free()

func test_random_picks_from_its_pool_and_swap_keeps_switching() -> void:
	var design := RoomDesign.new()
	design.set_object(SERVER_AT, "server")
	design.set_server_buff(SERVER_AT, ServerBuff.RANDOM_SWAP)
	design.set_server_pool(SERVER_AT, "attack", false)
	var room := await boot_design(design)
	var server := find_server(room)
	var pool := [ServerBuff.Kind.DEFENSE, ServerBuff.Kind.SPEED]
	expect(server.kind in pool, "it starts on a boost from its pool")
	var first := server.kind
	server._swap()
	expect(server.kind in pool && server.kind != first, "a swap moves to the other boost in its pool")
	expect_equal(server.area_color(), ServerBuff.SWAP_COLOR, "its tint stays pink whatever it gives")

func test_design_keeps_and_exports_server_settings() -> void:
	var design := RoomDesign.new()
	design.set_object(SERVER_AT, "server")
	design.set_object(NEAR, "goblin")
	expect_equal(design.enemy_count(), 1, "servers aren't counted as enemies to beat")
	var before := design.snapshot()
	design.set_server_buff(SERVER_AT, "defense")
	design.set_radius(SERVER_AT, 60.0)
	design.record(before)
	expect(design.to_text().contains("servers:\n6,6 defense 60"), "the export lists it")
	expect(!design.to_text().contains("detection_radius:\n6,6"), "its radius isn't a detection radius")
	design.undo()
	expect_equal(design.server_at(SERVER_AT).buff, ServerBuff.RANDOM, "undo puts its boost back")
	expect_equal(design.radius_at(SERVER_AT), RoomDesign.SERVER_DEFAULT_RADIUS, "and its radius")
	design.set_server_pool(SERVER_AT, "attack", false)
	design.set_server_pool(SERVER_AT, "defense", false)
	design.set_server_pool(SERVER_AT, "speed", false)
	expect_equal(design.server_at(SERVER_AT).pool, ["speed"], "the last boost in the pool stays")

func test_area_tint_is_on_its_room_and_goes_with_it() -> void:
	var room := await boot_server("defense")
	var server := find_server(room)
	await tree.process_frame
	var area: ServerArea = null
	for child in room.get_children():
		if child is ServerArea:
			area = child
	expect(area != null, "its area is drawn on the room")
	if area == null:
		return
	expect_equal(area._color, ServerBuff.COLORS[ServerBuff.Kind.DEFENSE], "tinted the defense boost's colour")
	expect(area.visible && area.is_visible_in_tree(), "and visible")
	sword_hits(server, 3)
	await tree.process_frame
	expect(!is_instance_valid(area) || area.is_queued_for_deletion(), "it goes when the server breaks")

func test_pixel_ring_stays_inside_its_radius() -> void:
	var pieces := ServerArea.disc_rows(Vector2.ZERO, 50.0)
	expect(!pieces.is_empty(), "a disc has rows")
	var ring := 0
	for piece: Array in pieces:
		var rect: Rect2 = piece[0]
		for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
			expect((corner as Vector2).length() <= 50.0 + ServerArea.PIXEL * 1.5, "every block is inside the circle")
		if piece[1]:
			ring += 1
	expect(ring > 0, "it has a ring round the edge")
