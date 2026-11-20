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
	expect_equal(Room.INNER_WALL_ATLAS.size(), 16, "a piece for each of the 16 masks")
	var seen := {}
	for mask: int in Room.INNER_WALL_ATLAS:
		seen[Room.INNER_WALL_ATLAS[mask]] = true
	expect_equal(seen.size(), 16, "each piece used once")

func test_design_paints_joined_pieces() -> void:
	var room := l_design().build_room()
	expect_equal(atlas_at(room, Vector2i(2, 2)), Room.INNER_WALL_ATLAS[2 | 4], "corner joins right and down")
	expect_equal(atlas_at(room, Vector2i(3, 2)), Room.INNER_WALL_ATLAS[8], "end joins left")
	expect_equal(atlas_at(room, Vector2i(2, 3)), Room.INNER_WALL_ATLAS[1], "foot joins up")
	expect(!RoomDesign.is_walkable(RoomDesign.Cell.INNER_WALL), "walls aren't walkable")
	expect(l_design().to_text().contains("X"), "exported as X")
	room.free()

func test_room_rejoins_walls_on_load() -> void:
	var room := l_design().build_room()
	# Scrambled pieces, as a room scene painted by hand might have; the room fixes them.
	for index: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		walls(room).set_cell(0, RoomDesign.tile_cell(index), 0, Room.INNER_WALL_ATLAS[15])
	room._join_inner_walls()
	expect_equal(atlas_at(room, Vector2i(2, 2)), Room.INNER_WALL_ATLAS[6], "corner after joining")
	expect_equal(atlas_at(room, Vector2i(2, 3)), Room.INNER_WALL_ATLAS[1], "foot after joining")
	room.free()

func test_walls_block_enemies() -> void:
	Overworld.test_design = l_design()
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	var room: Room = autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)
	await tree.physics_frame # Tile collision is in the physics world from here
	expect(!room.nav().is_open(RoomDesign.cell_centre(Vector2i(2, 2))), "enemies path round walls")
	expect(room.nav().is_open(RoomDesign.cell_centre(Vector2i(5, 5))), "but not round floor")
