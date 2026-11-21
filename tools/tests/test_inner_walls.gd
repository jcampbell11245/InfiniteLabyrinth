extends "res://tools/tests/test_case.gd"

# Inner walls: the rooms' solid blocks, drawn from one atlas with a piece for each set of
# joined neighbours. Checks the pieces a design paints, that a room joins them again when
# it loads, and that nothing walks through them.

func walls(room: Node) -> TileMap:
	return room.get_node("InnerWalls")

# An L of walls: (2, 2) and (3, 2) across, (2, 3) below the first.
func l_design() -> RoomDesign:
	var design := RoomDesign.new()
	for index: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		design.set_cell(index, RoomDesign.Cell.INNER_WALL)
	return design

func atlas_at(room: Node, index: Vector2i) -> Vector2i:
	return walls(room).get_cell_atlas_coords(0, RoomDesign.tile_cell(index))

func test_atlas_covers_every_neighbour_set() -> void:
	var seen := {}
	for mask: int in InnerWalls.BASE_ATLAS:
		seen[InnerWalls.BASE_ATLAS[mask]] = true
	for extra in InnerWalls.extras():
		seen[InnerWalls.atlas_for(extra.x, extra.y)] = true
	expect_equal(InnerWalls.extras().size(), 31, "an inside-corner piece for each case")
	expect_equal(seen.size(), 47, "each of the 47 pieces in its own cell")
	for cell: Vector2i in seen:
		expect(cell.x < InnerWalls.COLUMNS && cell.y < InnerWalls.rows(), "%s is on the sheet" % cell)

func test_joined_sheet_is_up_to_date() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(InnerWalls.SOURCE))
	var saved := Image.load_from_file(ProjectSettings.globalize_path(InnerWalls.JOINED))
	saved.convert(Image.FORMAT_RGBA8)
	expect(InnerWalls.build_image(source).get_data() == saved.get_data(),
		"inner_walls_joined.png matches inner_walls.png (run tools/build_inner_walls.gd)")

func test_inside_corners_get_their_own_piece() -> void:
	# A 2x2 block with its top-left missing: (1, 1) has walls above and to the left, but
	# floor diagonally between them.
	var design := RoomDesign.new()
	for index: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		design.set_cell(index, RoomDesign.Cell.INNER_WALL)
	var room := design.build_room()
	expect_equal(atlas_at(room, Vector2i(2, 2)), InnerWalls.atlas_for(1 | 8, 0b0001), "top-left cut in")
	design.set_cell(Vector2i(1, 1), RoomDesign.Cell.INNER_WALL)
	design.paint(room, Vector2i(1, 1))
	expect_equal(atlas_at(room, Vector2i(2, 2)), InnerWalls.BASE_ATLAS[1 | 8], "a full block")
	design.set_cell(Vector2i(1, 1), RoomDesign.Cell.FLOOR)
	design.set_cell(Vector2i(3, 2), RoomDesign.Cell.INNER_WALL)
	design.set_cell(Vector2i(2, 3), RoomDesign.Cell.INNER_WALL)
	design.paint_all(room)
	expect_equal(atlas_at(room, Vector2i(2, 2)), InnerWalls.atlas_for(15, 0b1111),
		"a plus has all four corners cut in")
	room.free()

func test_design_paints_joined_pieces() -> void:
	var room := l_design().build_room()
	expect_equal(atlas_at(room, Vector2i(2, 2)), InnerWalls.atlas_for(2 | 4, 0b0100), "corner, with its inside corner cut in")
	expect_equal(atlas_at(room, Vector2i(3, 2)), InnerWalls.BASE_ATLAS[8], "end joins left")
	expect_equal(atlas_at(room, Vector2i(2, 3)), InnerWalls.BASE_ATLAS[1], "foot joins up")
	expect(!RoomDesign.is_walkable(RoomDesign.Cell.INNER_WALL), "walls aren't walkable")
	expect(l_design().to_text().contains("X"), "exported as X")
	room.free()

func test_room_rejoins_walls_on_load() -> void:
	var room := l_design().build_room()
	# Scrambled pieces, as a room scene painted by hand might have; the room fixes them.
	for index: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		walls(room).set_cell(0, RoomDesign.tile_cell(index), 0, InnerWalls.BASE_ATLAS[15])
	room._join_inner_walls()
	expect_equal(atlas_at(room, Vector2i(2, 2)), InnerWalls.atlas_for(6, 0b0100), "corner after joining")
	expect_equal(atlas_at(room, Vector2i(2, 3)), InnerWalls.BASE_ATLAS[1], "foot after joining")
	room.free()

func test_walls_block_enemies() -> void:
	Overworld.test_design = l_design()
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	var room: Room = autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)
	await tree.physics_frame # Tile collision is in the physics world from here
	expect(!room.nav().is_open(RoomDesign.cell_centre(Vector2i(2, 2))), "enemies path round walls")
	expect(room.nav().is_open(RoomDesign.cell_centre(Vector2i(5, 5))), "but not round floor")
