extends "res://tools/tests/test_case.gd"

# Special floor tiles (SpecialTiles): each test builds a room from a RoomDesign, as the room
# creator's play-test does, puts the player on a tile and checks what the tile does.

const SPAWN := Vector2i(0, 6) # Where the play-test puts the player in an empty design

# Plays `design` as a one-room floor, as the room creator's Play button does.
func boot_design(design: RoomDesign) -> Room:
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	return autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)

func player() -> Player:
	return autoload("Game").player

# Stands the player with their feet in the middle of floor cell `index`.
func stand_on(room: Room, index: Vector2i) -> void:
	player().global_position = room.to_global(RoomDesign.cell_centre(index)) - Player.FEET

func feet_index(room: Room) -> Vector2i:
	var feet := room.to_local(player().global_position + Player.FEET)
	return RoomDesign.floor_index(Vector2i((feet / Room.CELL_SIZE).floor()))

func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame

func layer(room: Room) -> SpecialTiles:
	return room.get_node(SpecialTiles.NODE_NAME)

func test_export_lists_special_tiles() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(0, 0), RoomDesign.Cell.SPIKES)
	design.set_cell(Vector2i(1, 0), RoomDesign.Cell.WIRES)
	design.set_cell(Vector2i(2, 0), RoomDesign.Cell.TELEPORT_2)
	var grid_row := design.to_text().split("grid:\n")[1].split("\n")[0]
	expect(grid_row.begins_with("^E2"), "first row starts with spikes, wires, teleporter 2: " + grid_row)
	expect(design.clear_problem().contains("teleporter"), "a lone teleporter is warned about")
	design.set_cell(Vector2i(5, 5), RoomDesign.Cell.TELEPORT_2)
	expect(!design.clear_problem().contains("teleporter"), "a pair isn't")

func test_special_tiles_keep_enemy_paths() -> void:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), "goblin")
	design.set_roam_mode(Vector2i(6, 6), "path")
	design.set_cell(Vector2i(8, 6), RoomDesign.Cell.SLICK)
	expect(design.add_path_point(Vector2i(6, 6), Vector2i(8, 6)), "a path can cross a special tile")
	design.set_cell(Vector2i(8, 6), RoomDesign.Cell.PIT)
	expect(design.path_points(Vector2i(6, 6)).is_empty(), "but not a pit")

func test_spikes_hurt_on_stepping_on() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(3, 6), RoomDesign.Cell.SPIKES)
	var room: Room = await boot_design(design)
	var before := player().level_countdown.time_left
	stand_on(room, Vector2i(3, 6))
	await physics_frames(3)
	var tuning := autoload("Tuning")
	expect_near(before - player().level_countdown.time_left,
		maxf(tuning.spike_damage * tuning.seconds_per_damage, 1.0), 0.3, "seconds taken by the spikes")

func test_teleporter_sends_to_its_partner() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(3, 3), RoomDesign.Cell.TELEPORT_1)
	design.set_cell(Vector2i(9, 9), RoomDesign.Cell.TELEPORT_1)
	design.set_cell(Vector2i(9, 3), RoomDesign.Cell.TELEPORT_3) # Unpaired: does nothing
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(3, 3))
	await physics_frames(5)
	expect_equal(feet_index(room), Vector2i(9, 9), "arrived on the partner square")
	stand_on(room, Vector2i(9, 3))
	await physics_frames(5)
	expect_equal(feet_index(room), Vector2i(9, 3), "an unpaired teleporter stays put")

func test_cracked_floor_gives_way_then_mends() -> void:
	var tuning := autoload("Tuning")
	tuning.crack_time = 0.1
	tuning.crack_respawn_time = 0.4
	var design := RoomDesign.new()
	design.set_cell(Vector2i(3, 6), RoomDesign.Cell.CRACKED)
	var room: Room = await boot_design(design)
	var cell := RoomDesign.tile_cell(Vector2i(3, 6))
	tuning.god_mode = true # The fall would take time off
	stand_on(room, Vector2i(3, 6))
	await wait_real(0.25)
	expect(layer(room).is_hole(cell), "a hole after being stood on")
	expect(!room.is_safe_ground(cell), "not somewhere to respawn")
	await wait_real(1.6) # Past the fall and the hole's time
	expect(!layer(room).is_hole(cell), "mended")

func test_paste_takes_three_rolls_to_escape() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.PASTE)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(4, 6))
	await physics_frames(3)
	stand_on(room, Vector2i(8, 6)) # Yanked well out of reach
	await physics_frames(3)
	expect(feet_index(room).x <= 5, "pulled back to the paste, at %s" % feet_index(room))
	var rolls: int = autoload("Tuning").paste_rolls_to_escape
	for roll in rolls:
		player().rolling.start(0.2) # As a roll does
		await physics_frames(2)
		player().rolling.stop()
		await physics_frames(2)
		stand_on(room, Vector2i(8, 6))
		await physics_frames(3)
		if roll < rolls - 1:
			expect(feet_index(room).x <= 5, "still held after roll %d" % (roll + 1))
	expect_equal(feet_index(room), Vector2i(8, 6), "free after %d rolls" % rolls)

func test_paste_never_wears_off() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.PASTE)
	var room: Room = await boot_design(design)
	var cell := RoomDesign.tile_cell(Vector2i(4, 6))
	stand_on(room, Vector2i(4, 6))
	await wait_real(3.0)
	expect(layer(room).get_cell_source_id(0, cell) != -1, "still there")
	expect(SpecialTiles.is_stuck_in(room, player()), "still holding the player")

func test_pressure_plate_rises_when_left() -> void:
	autoload("Tuning").plate_delay = 5.0 # Stays clicked down, not live, while we look
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.PLATE)
	var room: Room = await boot_design(design)
	var cell := RoomDesign.tile_cell(Vector2i(4, 6))
	stand_on(room, Vector2i(4, 6))
	await physics_frames(3)
	expect_equal(layer(room).get_cell_atlas_coords(0, cell).x, SpecialTiles.Frame.PLATE_DOWN, "pressed while stood on")
	stand_on(room, Vector2i(8, 6))
	await physics_frames(2)
	expect_equal(layer(room).get_cell_atlas_coords(0, cell).x, SpecialTiles.Frame.PLATE, "raised as soon as it's left")

func test_enemies_crawl_in_paste() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.PASTE)
	design.set_object(Vector2i(4, 6), "goblin")
	design.set_facing(Vector2i(4, 6), Direction.LEFT)
	design.set_radius(Vector2i(4, 6), 0.0)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(12, 0))
	var goblin: Enemy = null
	for child in room.get_children():
		if child is Enemy:
			goblin = child
	var free_step := goblin.ground_motion(Vector2(1, 0), 1.0 / 60.0)
	goblin.global_position += room.to_global(RoomDesign.cell_centre(Vector2i(6, 6))) - goblin.feet_position()
	await physics_frames(3)
	expect(SpecialTiles.is_stuck_in(room, goblin), "caught")
	var stuck_step := goblin.ground_motion(Vector2(1, 0), 1.0 / 60.0)
	expect_near(stuck_step.length() / free_step.length(), autoload("Tuning").paste_enemy_speed, 0.01,
		"walks at the paste speed")

func test_swinging_into_live_wires_breaks_them() -> void:
	var tuning := autoload("Tuning")
	tuning.wire_idle_time = 100.0 # Only goes live when told to
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.WIRES)
	var room: Room = await boot_design(design)
	var cell := RoomDesign.tile_cell(Vector2i(4, 6))
	stand_on(room, Vector2i(3, 6))
	player().direction = Direction.RIGHT
	layer(room)._go_live(cell)
	Input.action_press("melee_attack")
	await physics_frames(4)
	Input.action_release("melee_attack")
	await physics_frames(2)
	expect_equal(layer(room)._tiles[cell].phase, SpecialTiles.Phase.BROKEN, "broken by the swing")
	expect(!layer(room).avoided_cells().has(cell), "enemies no longer avoid it")

# Enemies walk round a trap when the way round is short, but cut across a long wall of them
# (Tuning.trap_avoid_weight) rather than go far out of their way.
func test_enemies_walk_round_small_traps_but_cut_across_long_ones() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 3), RoomDesign.Cell.SPIKES) # One trap in the way, top half
	for y in range(6, 13): # A wall of spikes from the middle to the bottom edge
		design.set_cell(Vector2i(6, y), RoomDesign.Cell.SPIKES)
	var room: Room = await boot_design(design)
	await tree.physics_frame
	var nav := room.nav()
	var spikes := RoomDesign.cell_centre(Vector2i(6, 3))
	expect(nav.is_avoided(spikes) && !nav.is_open(spikes), "spikes are avoided")
	var top_left := RoomDesign.cell_centre(Vector2i(3, 3))
	var top_right := RoomDesign.cell_centre(Vector2i(9, 3))
	expect(!nav.is_clear_line(top_left, top_right), "no walking straight across one")
	var round_one := nav.next_waypoint(top_left, top_right)
	expect(absf(round_one.y - top_left.y) >= Room.CELL_SIZE / 2.0, "steps round the one trap, to %s" % round_one)
	var bottom_left := RoomDesign.cell_centre(Vector2i(4, 11))
	var bottom_right := RoomDesign.cell_centre(Vector2i(8, 11))
	var across := nav.next_waypoint(bottom_left, bottom_right)
	expect(absf(across.y - bottom_left.y) < Room.CELL_SIZE * 2, "cuts across the long wall, to %s" % across)

func test_teleporter_takes_feet_brushing_its_edge() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.TELEPORT_1)
	design.set_cell(Vector2i(10, 2), RoomDesign.Cell.TELEPORT_1)
	var room: Room = await boot_design(design)
	# Feet a few pixels above the teleporter's row, walking in from the left along its edge.
	stand_on(room, Vector2i(3, 6))
	player().global_position.y -= Room.CELL_SIZE / 2.0 + SpecialTiles.TELEPORT_GRACE - 2.0
	await physics_frames(2)
	Input.action_press("right")
	var arrived := false
	for i in 90:
		await tree.physics_frame
		if feet_index(room) == Vector2i(10, 2):
			arrived = true
			break
	Input.action_release("right")
	expect(arrived, "went through, though the middle of the feet never crossed the square")

func test_projectiles_go_through_teleporters() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.TELEPORT_2)
	design.set_cell(Vector2i(6, 1), RoomDesign.Cell.TELEPORT_2)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(0, 12)) # Out of the way
	var arrow: Projectile = (load("res://src/projectiles/Arrow.tscn") as PackedScene).instantiate()
	room.add_child(arrow)
	arrow.global_position = room.to_global(RoomDesign.cell_centre(Vector2i(3, 6))) - SpecialTiles.PROJECTILE_DROP
	arrow.direction = Direction.RIGHT
	arrow.speed = 120.0
	var went := false
	for i in 90:
		await tree.physics_frame
		if !is_instance_valid(arrow):
			break
		var under := room.to_local(arrow.global_position + SpecialTiles.PROJECTILE_DROP)
		if RoomDesign.floor_index(Vector2i((under / Room.CELL_SIZE).floor())).y == 1:
			went = true
			expect_equal(arrow.direction, Direction.RIGHT, "still flying the same way")
			break
	expect(went, "the arrow came out of the other teleporter")
	if is_instance_valid(arrow):
		arrow.queue_free()

func test_destination_glows_when_near() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.TELEPORT_3)
	design.set_cell(Vector2i(10, 10), RoomDesign.Cell.TELEPORT_3)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(1, 1))
	await physics_frames(2)
	expect(layer(room).glowing_teleporter() == null, "no glow from far away")
	stand_on(room, Vector2i(5, 6)) # Next to it
	await physics_frames(2)
	expect_equal(layer(room).glowing_teleporter(), RoomDesign.tile_cell(Vector2i(10, 10)), "its partner glows")

func test_parryable_traps_twinkle_as_they_go_live() -> void:
	autoload("Tuning").wire_idle_time = 100.0
	var design := RoomDesign.new()
	design.set_cell(Vector2i(8, 8), RoomDesign.Cell.WIRES)
	var room: Room = await boot_design(design)
	var tiles := layer(room)
	var before := tiles.get_child_count()
	tiles._go_live(RoomDesign.tile_cell(Vector2i(8, 8)))
	expect(tiles.get_child_count() > before, "a twinkle appears on the wires")

func test_enemies_keep_sliding_on_ice() -> void:
	var design := RoomDesign.new()
	for x in range(2, 12):
		for y in range(4, 9):
			design.set_cell(Vector2i(x, y), RoomDesign.Cell.SLICK)
	design.set_object(Vector2i(4, 6), "goblin")
	design.set_facing(Vector2i(4, 6), Direction.LEFT) # Away from the player, so it stands still
	design.set_radius(Vector2i(4, 6), 0.0)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(12, 0)) # Behind it and far off: any movement is the slide
	var goblin: Enemy = null
	for child in room.get_children():
		if child is Enemy:
			goblin = child
	goblin.global_position.x += Room.CELL_SIZE * 2 # Off its own floor cell, onto the ice
	await physics_frames(2)
	var start := goblin.global_position
	goblin.slide = Vector2(goblin.speed, 0)
	await physics_frames(20)
	expect(goblin.global_position.x - start.x > 6.0, "still sliding after it stopped walking (moved %.1f px)"
		% (goblin.global_position.x - start.x))
	await wait_real(2.0)
	expect_equal(goblin.slide, Vector2.ZERO, "comes to a stop in the end")

# An arrow flies at chest height: shot sideways from the row below a teleporter, it's drawn
# right across the square though the floor under it isn't, and should still go through.
func test_arrow_drawn_across_a_teleporter_goes_through() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.TELEPORT_1)
	design.set_cell(Vector2i(1, 11), RoomDesign.Cell.TELEPORT_1)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(3, 7)) # The row below
	player().global_position.y -= 6.0 # Arrow drawn about the square's middle
	player().direction = Direction.RIGHT
	await physics_frames(3)
	Input.action_press("ranged_attack")
	await physics_frames(2)
	Input.action_release("ranged_attack")
	var went := false
	for i in 60:
		await tree.physics_frame
		for node in tree.get_nodes_in_group(SpecialTiles.PROJECTILE_GROUP):
			var under := room.to_local((node as Node2D).global_position + SpecialTiles.PROJECTILE_DROP)
			if RoomDesign.floor_index(Vector2i((under / Room.CELL_SIZE).floor())) == Vector2i(1, 11):
				went = true
		if went:
			break
	expect(went, "the arrow came out of the partner teleporter")

func test_paste_bar_counts_down_the_rolls() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.PASTE)
	var room: Room = await boot_design(design)
	expect_equal(SpecialTiles.paste_left_in(room, player()), 0.0, "no bar before it's caught")
	stand_on(room, Vector2i(4, 6))
	await physics_frames(3)
	expect_near(SpecialTiles.paste_left_in(room, player()), 1.0, 0.001, "full when caught")
	var rolls: int = autoload("Tuning").paste_rolls_to_escape
	player().rolling.start(0.2)
	await physics_frames(2)
	player().rolling.stop()
	await physics_frames(2)
	expect_near(SpecialTiles.paste_left_in(room, player()), float(rolls - 1) / rolls, 0.001, "down a roll's worth")

func test_speed_tile_speeds_up_and_shows_its_status() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(5, 6), RoomDesign.Cell.FAST)
	design.set_cell(Vector2i(8, 6), RoomDesign.Cell.SLOW)
	var room: Room = await boot_design(design)
	var tuning := autoload("Tuning")
	stand_on(room, Vector2i(5, 6))
	await physics_frames(3)
	expect_near(player()._ground_factor, tuning.fast_tile_multiplier, 0.001, "faster on a speed tile")
	stand_on(room, Vector2i(8, 6))
	await physics_frames(3)
	expect_near(player()._ground_factor, tuning.slow_tile_multiplier, 0.001, "slower on a slow tile")
	stand_on(room, Vector2i(2, 2))
	await physics_frames(3)
	expect_near(player()._ground_factor, 1.0, 0.001, "normal off them")

# Rolls in place (facing right, no direction held) using the real roll input.
func roll_right() -> void:
	player().direction = Direction.RIGHT
	Input.action_press("roll")
	await physics_frames(2)
	Input.action_release("roll")
	await wait_real(Tuning.roll_duration + 0.3)

func test_rolling_over_spikes_in_one_roll_takes_no_hit() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(5, 6), RoomDesign.Cell.SPIKES)
	design.set_cell(Vector2i(10, 6), RoomDesign.Cell.SPIKES)
	design.set_cell(Vector2i(11, 6), RoomDesign.Cell.SPIKES)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(4, 6))
	await physics_frames(3)
	var before := player().level_countdown.time_left
	await roll_right()
	expect(feet_index(room).x >= 6, "the roll cleared the spikes (feet at %s)" % feet_index(room))
	expect_near(player().level_countdown.time_left, before, 0.6, "no time taken rolling over them")
	# A roll that ends on spikes still hurts.
	stand_on(room, Vector2i(9, 6))
	await wait_real(0.6) # Roll cooldown
	before = player().level_countdown.time_left
	await roll_right()
	expect(feet_index(room).x in [10, 11], "the roll ended on the spikes (feet at %s)" % feet_index(room))
	expect(before - player().level_countdown.time_left > 1.0, "hurt for landing on them")

func test_teleporters_squish_the_way_they_are_entered() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(6, 6), RoomDesign.Cell.TELEPORT_1)
	design.set_cell(Vector2i(10, 2), RoomDesign.Cell.TELEPORT_1)
	var room: Room = await boot_design(design)
	var tiles := layer(room)
	var entry := RoomDesign.tile_cell(Vector2i(6, 6))
	var exit := RoomDesign.tile_cell(Vector2i(10, 2))
	stand_on(room, Vector2i(6, 6))
	player().global_position.x -= 10.0 # Feet coming in from the left
	await physics_frames(6) # Into the squash
	expect(tiles._squishes.has(entry) && tiles._squishes.has(exit), "both squares squish")
	if tiles._squishes.has(entry):
		var squashed: Vector2 = (tiles._squishes[entry] as Sprite2D).scale
		expect(squashed.x < 1.0 && squashed.y > 1.0, "the entered square squashes left to right: %s" % squashed)
	if tiles._squishes.has(exit):
		var stretched: Vector2 = (tiles._squishes[exit] as Sprite2D).scale
		expect(stretched.x > 1.0, "the far square stretches out the same way: %s" % stretched)
	expect(tiles.teleport_destination(exit) == entry, "still pairs up while squished")
	await wait_real(SpecialTiles.SQUISH_IN_TIME + SpecialTiles.SQUISH_HOLD + SpecialTiles.SQUISH_TIME + 0.3)
	expect(tiles._squishes.is_empty(), "sprung back")
	expect(tiles.get_cell_source_id(0, entry) != -1 && tiles.get_cell_source_id(0, exit) != -1, "drawn again")
