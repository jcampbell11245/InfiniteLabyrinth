extends "res://tools/tests/test_case.gd"

# WorldGenerator: the floor layout's shape, the start, end and key rooms, and that every
# room scene it can pick loads.

func test_layout_shape() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var layout := WorldGenerator.generate(rng, 1)
	expect_equal(layout.size(), WorldGenerator.LAYOUT_ROWS, "rows")
	for row in layout.size():
		expect_equal(layout[row].size(), WorldGenerator.LAYOUT_COLUMNS, "columns in row %d" % row)
	var middle := WorldGenerator.MIDDLE_ROW
	var last := WorldGenerator.LAYOUT_COLUMNS - 1
	expect_equal(layout[middle][0], WorldGenerator.START_ROOM, "start room on the middle row, left")
	expect_equal(layout[middle][last], WorldGenerator.END_ROOM, "end room on the middle row, right")
	for row in layout.size():
		if row != middle:
			expect_equal(layout[row][0], "", "nothing left of the grid on row %d" % row)
			expect_equal(layout[row][last], "", "nothing right of the grid on row %d" % row)
		for col in range(1, last):
			expect(layout[row][col] != "", "a room at row %d, column %d" % [row, col])

func test_three_key_rooms_in_distinct_rows_and_columns() -> void:
	for seed in [1, 2, 3, 99, 2026]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var layout := WorldGenerator.generate(rng, 1)
		var rows := {}
		var cols := {}
		for row in layout.size():
			for col in layout[row].size():
				if layout[row][col].begins_with(WorldGenerator.KEYROOMS_DIR):
					rows[row] = true
					cols[col] = true
		expect_equal(rows.size(), 3, "seed %d: key rooms in 3 different rows" % seed)
		expect_equal(cols.size(), 3, "seed %d: key rooms in 3 different columns" % seed)

func test_every_room_scene_loads_as_a_room() -> void:
	var paths := WorldGenerator.list_scenes(WorldGenerator.ROOMS_DIR) \
		+ WorldGenerator.list_scenes(WorldGenerator.KEYROOMS_DIR)
	paths.append_array([WorldGenerator.START_ROOM, WorldGenerator.END_ROOM, WorldGenerator.BOSS_ROOM])
	expect(paths.size() > 10, "found the room scenes")
	for path in paths:
		var packed := WorldGenerator.scene(path)
		expect(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var room := packed.instantiate()
		expect(room is Room, "%s's root is a Room" % path)
		room.free()

func test_every_floor_has_rooms() -> void:
	var all := WorldGenerator.list_scenes(WorldGenerator.ROOMS_DIR)
	for floor_number in range(1, 11):
		expect(!WorldGenerator.rooms_for_floor(all, floor_number).is_empty(),
			"some room can appear on floor %d" % floor_number)
