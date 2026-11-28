class_name Overworld
extends Node2D

# One floor of the dungeon: builds the rooms from a WorldGenerator layout and runs the
# boss-door cutscene. Reloaded for every new floor.
#
# With test_design set (by the room creator) it builds just that room instead, with every
# door closed, to play-test it. F1, or dying, goes back to the room creator.
#
# With tutorial set (by F3 on the title screen) it builds the tutorial instead: the start
# room, TUTORIAL_ROOMS rooms from TUTORIAL_DIR in a line, then the end room, all on the
# middle row. There's no boss door, no timer (LevelCountdown) and no shop (Merchant), the
# end room's gate wants Tuning.tutorial_keys_to_finish keys, and its exit goes back to the
# title screen. It always uses floor 1's art and never touches the save.

# Top-left offset of the room grid; a room at (row, col) sits at GRID_ORIGIN + ROOM_SIZE * (col, row).
# Column 0 holds the start room, columns 1..COLUMNS the generated rooms, then the end room.
const GRID_ORIGIN := Vector2(-191, -168)
const ROOM_EDITOR := "res://src/editor/RoomEditor.tscn"
const TEST_ROOM_ID := 0
const TITLE_SCREEN := "res://src/ui/menus/TitleScreen.tscn"
const TUTORIAL_DIR := "res://src/world/tutorial/"
const TUTORIAL_ROOMS := 7 # Rooms between the start and end rooms, Tutorial1..Tutorial7
# Start room nodes for the boss fight, taken out of the tutorial's start room.
const BOSS_DOOR_NODES: Array[String] = ["BossDoor", "BossDoorBottom", "TransitionDetectorB"]

static var test_design: RoomDesign # Set while play-testing a room from the room creator
static var tutorial := false # Set while playing the tutorial; the title screen clears it

var floor_number := 1
var rooms_by_id := {} # room_id -> Room

func _enter_tree() -> void:
	Game.register(self)

func _exit_tree() -> void:
	Game.unregister(self)

func _ready() -> void:
	floor_number = 1 if tutorial else SaveData.floor_number
	add_child(CaveLighting.new())

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if is_test():
		_build_test(test_design)
	elif tutorial:
		_build_tutorial()
	else:
		_build(WorldGenerator.generate(rng, floor_number))
	# Some servers turn silver, into premium servers boosting the whole floor (a play-test rolls
	# too, for trying them).
	var premium := ServerBuff.roll_floor_servers(get_tree(), floor_number, rng)
	if !premium.is_empty():
		FloorBanner.show_for(self, premium)
	Game.room_entered.emit(Game.player.current_room) # Fades the start room in
	
	Music.start_floor()
	Game.player.boss_door_reached.connect(_on_player_boss_door_reached)
	Game.player.transition_pause_finished.connect(_on_player_transition_pause_finished)
	if rooms_by_id.has(Constants.BOSS_ROOM):
		var door_close: AudioStreamPlayer = rooms_by_id[Constants.BOSS_ROOM].get_node("BossDoorBody/BossDoorClose")
		door_close.finished.connect(_on_boss_door_closed)

func _unhandled_input(event: InputEvent) -> void:
	if is_test() && event is InputEventKey && event.pressed && (event as InputEventKey).keycode == KEY_F1:
		leave_test()

# True while play-testing a room from the room creator.
func is_test() -> bool:
	return test_design != null

func leave_test() -> void:
	get_tree().paused = false
	# Dying in a play-test leaves slow motion running; clear it so the editor and later
	# play-tests don't inherit it. Covers F1 as well as Return to Title.
	Juice.end_time_effects()
	Music.stop_all()
	get_tree().change_scene_to_file(ROOM_EDITOR)

func grid_position(row: int, col: int) -> Vector2:
	return GRID_ORIGIN + Constants.ROOM_SIZE * Vector2(col, row)

# The tutorial's scene for room `index` (0-based) of the line between the start and end rooms.
static func tutorial_room(index: int) -> String:
	return TUTORIAL_DIR + "Tutorial%d.tscn" % (index + 1)

# Leaves the finished tutorial for the title screen, saving nothing.
func finish_tutorial() -> void:
	get_tree().paused = false
	Juice.end_time_effects()
	Music.stop_all()
	get_tree().change_scene_to_file(TITLE_SCREEN)

func reset_world() -> void:
	SaveData.coins = Game.coins
	SaveData.save()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")

# Instances the rooms of a WorldGenerator layout, plus the boss room left of the start
# room, and closes every door that leads off the grid.
func _build(layout: Array[PackedStringArray]) -> void:
	var middle := WorldGenerator.MIDDLE_ROW
	var last_col := WorldGenerator.LAYOUT_COLUMNS - 1
	var start := _add_room(WorldGenerator.scene(layout[middle][0]), Constants.START_ROOM, middle, 0)
	start.close_door(Room.Door.TOP)
	start.close_door(Room.Door.BOTTOM)
	
	var boss := _add_room(WorldGenerator.scene(WorldGenerator.BOSS_ROOM), Constants.BOSS_ROOM, middle, -1)
	_attach_left_of(boss, start)
	boss.close_door(Room.Door.TOP)
	boss.close_door(Room.Door.BOTTOM)
	boss.close_door(Room.Door.LEFT)
	
	var end := _add_room(WorldGenerator.scene(layout[middle][last_col]), Constants.END_ROOM, middle, last_col)
	end.close_door(Room.Door.TOP)
	end.close_door(Room.Door.RIGHT)
	end.close_door(Room.Door.BOTTOM)
	end.add_key_gate()
	
	for row in range(WorldGenerator.LAYOUT_ROWS):
		for col in range(1, last_col):
			var room := _add_room(WorldGenerator.scene(layout[row][col]), Constants.COLUMNS * row + (col - 1), row, col)
			# The middle row's outer doors lead to the start and end rooms.
			if row == middle:
				continue
			if row == 0:
				room.close_door(Room.Door.TOP)
			elif row == WorldGenerator.LAYOUT_ROWS - 1:
				room.close_door(Room.Door.BOTTOM)
			if col == 1:
				room.close_door(Room.Door.LEFT)
			elif col == last_col - 1:
				room.close_door(Room.Door.RIGHT)

# Builds the tutorial: the start room (without its boss door), the tutorial rooms in a line
# along the middle row, then the end room, with every door off that line closed.
func _build_tutorial() -> void:
	var middle := WorldGenerator.MIDDLE_ROW
	var start: Room = WorldGenerator.scene(WorldGenerator.START_ROOM).instantiate()
	# Taken out before the room is added, so it builds its left wall as an ordinary side.
	for node_name in BOSS_DOOR_NODES:
		var node := start.get_node(node_name)
		start.remove_child(node)
		node.free()
	_place_room(start, Constants.START_ROOM, middle, 0)
	for door: Room.Door in [Room.Door.TOP, Room.Door.BOTTOM, Room.Door.LEFT]:
		start.close_door(door)

	for i in range(TUTORIAL_ROOMS):
		var room := _add_room(WorldGenerator.scene(tutorial_room(i)), i, middle, i + 1)
		room.close_door(Room.Door.TOP)
		room.close_door(Room.Door.BOTTOM)

	var end := _add_room(WorldGenerator.scene(WorldGenerator.END_ROOM), Constants.END_ROOM, middle, TUTORIAL_ROOMS + 1)
	end.close_door(Room.Door.TOP)
	end.close_door(Room.Door.RIGHT)
	end.close_door(Room.Door.BOTTOM)
	end.add_key_gate()

# Builds the room creator's design on its own, with the player on it and every door shut.
func _build_test(design: RoomDesign) -> void:
	var room := design.build_room()
	room.room_id = TEST_ROOM_ID
	add_child(room)
	room.position = grid_position(WorldGenerator.MIDDLE_ROW, 0)
	rooms_by_id[TEST_ROOM_ID] = room
	for door: Room.Door in [Room.Door.TOP, Room.Door.RIGHT, Room.Door.BOTTOM, Room.Door.LEFT]:
		room.close_door(door)
	var player := Game.player
	player.current_room = TEST_ROOM_ID
	player.position = room.position + room.tiles.map_to_local(RoomDesign.tile_cell(design.spawn_index())) 		+ Player.RESPAWN_OFFSET
	player.last_tile = player.position
	Game.camera_rig.position = room.position + room.centre
	var hint := Label.new()
	hint.text = "Testing room  -  F1: back to the room creator"
	hint.add_theme_font_size_override("font_size", 26)
	hint.position = Vector2(40, get_viewport().get_visible_rect().size.y - 70)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)

# Moves `room` so its right door opens onto `neighbour`'s left door. Needed for the boss
# room, which is smaller than the grid's rooms.
func _attach_left_of(room: Room, neighbour: Room) -> void:
	var right_door: Vector2 = room.tiles.map_to_local(room.door_cells[Room.Door.RIGHT])
	var left_door: Vector2 = neighbour.tiles.map_to_local(neighbour.door_cells[Room.Door.LEFT])
	room.position = neighbour.position + left_door - right_door - Vector2(Room.CELL_SIZE, 0)

func _add_room(scene: PackedScene, id: int, row: int, col: int) -> Room:
	return _place_room(scene.instantiate(), id, row, col)

func _place_room(room: Room, id: int, row: int, col: int) -> Room:
	add_child(room)
	room.position = grid_position(row, col)
	room.room_id = id
	rooms_by_id[id] = room
	return room

# Boss door sequence: the player steps on the start room's trigger, the door opens and the
# player walks through (StartRoom calls player.start_transition() once it's open). When the
# transition pause ends in the boss room, the door slams shut and the boss music starts.
func _on_player_boss_door_reached() -> void:
	var start: Room = rooms_by_id[Constants.START_ROOM]
	Music.stop_dungeon()
	start.get_node("BossDoor/BossDoorOpen").play()
	Game.camera.shake(3.7, 20, 1)
	start.get_node("BossDoor").play("opening")

func _on_player_transition_pause_finished() -> void:
	if Game.player.current_room == Constants.BOSS_ROOM && !Music.is_boss_playing():
		var door: Node = rooms_by_id[Constants.BOSS_ROOM].get_node("BossDoorBody")
		door.get_node("BossDoorClose").play()
		door.get_node("BossDoor").play("closing")
		door.get_node("CollisionShape2D").disabled = false
	else:
		Game.player.end_transition()

func _on_boss_door_closed() -> void:
	Game.player.end_transition()
	Music.play_boss()
