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

func test_paste_holds_until_a_roll() -> void:
	var design := RoomDesign.new()
	design.set_cell(Vector2i(4, 6), RoomDesign.Cell.PASTE)
	var room: Room = await boot_design(design)
	stand_on(room, Vector2i(4, 6))
	await physics_frames(3)
	stand_on(room, Vector2i(8, 6)) # Yanked well out of reach
	await physics_frames(3)
	expect(feet_index(room).x <= 5, "pulled back to the paste, at %s" % feet_index(room))
	player().rolling.start(0.2) # As a roll does
	await physics_frames(2)
	stand_on(room, Vector2i(8, 6))
	await physics_frames(3)
	expect_equal(feet_index(room), Vector2i(8, 6), "free after rolling")

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

func test_enemies_walk_round_traps() -> void:
	var design := RoomDesign.new()
	for y in range(2, 11): # A wall of spikes down the middle, open at top and bottom
		design.set_cell(Vector2i(6, y), RoomDesign.Cell.SPIKES)
	var room: Room = await boot_design(design)
	await tree.physics_frame
	var nav := room.nav()
	var left := RoomDesign.cell_centre(Vector2i(3, 6))
	var right := RoomDesign.cell_centre(Vector2i(9, 6))
	var spikes := RoomDesign.cell_centre(Vector2i(6, 6))
	expect(nav.is_avoided(spikes) && !nav.is_open(spikes), "spikes are avoided")
	expect(!nav.is_clear_line(left, right), "no walking straight across them")
	var waypoint := nav.next_waypoint(left, right)
	expect(absf(waypoint.y - left.y) > Room.CELL_SIZE * 2, "heads round the end of the spikes, to %s" % waypoint)
