class_name Overworld
extends Node2D

# One floor of the dungeon: builds the rooms from a WorldGenerator layout and runs the
# boss-door cutscene. Reloaded for every new floor.

# Top-left offset of the room grid; a room at (row, col) sits at GRID_ORIGIN + ROOM_SIZE * (col, row).
# Column 0 holds the start room, columns 1..COLUMNS the generated rooms, then the end room.
const GRID_ORIGIN := Vector2(-191, -168)
const BossRoom := preload("res://src/world/special/BossRoom.tscn")

var floor_number := 1
var rooms_by_id := {} # room_id -> Room

func _enter_tree() -> void:
	Game.register(self)

func _exit_tree() -> void:
	Game.unregister(self)

func _ready() -> void:
	floor_number = SaveData.floor_number
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_build(WorldGenerator.generate(rng))
	# BUG(see BUGS.md): the player starts with current_room 0, so room 0 acts as entered
	# (fades in and locks its doors) until the start room's detector fires.
	Game.room_entered.emit(Game.player.current_room)
	
	Music.start_floor()
	Game.player.boss_door_reached.connect(_on_player_boss_door_reached)
	Game.player.transition_pause_finished.connect(_on_player_transition_pause_finished)
	var door_close: AudioStreamPlayer = rooms_by_id[Constants.BOSS_ROOM].get_node("BossDoorBody/BossDoorClose")
	door_close.finished.connect(_on_boss_door_closed)

func grid_position(row: int, col: int) -> Vector2:
	return GRID_ORIGIN + Constants.ROOM_SIZE * Vector2(col, row)

func reset_world() -> void:
	SaveData.coins = Game.coins
	SaveData.save()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")

# Instances the rooms of a WorldGenerator layout, plus the boss room left of the start
# room, and closes every door that leads off the grid.
func _build(layout: Array[PackedStringArray]) -> void:
	var middle := WorldGenerator.MIDDLE_ROW
	var last_col := WorldGenerator.LAYOUT_COLUMNS - 1
	var start := _add_room(load(layout[middle][0]), Constants.START_ROOM, middle, 0)
	start.close_door(Room.Door.TOP)
	start.close_door(Room.Door.BOTTOM)
	
	var boss := _add_room(BossRoom, Constants.BOSS_ROOM, middle, -1)
	boss.close_door(Room.Door.TOP)
	boss.close_door(Room.Door.BOTTOM)
	boss.close_door(Room.Door.LEFT)
	
	var end := _add_room(load(layout[middle][last_col]), Constants.END_ROOM, middle, last_col)
	end.close_door(Room.Door.TOP)
	end.close_door(Room.Door.RIGHT)
	end.close_door(Room.Door.BOTTOM)
	
	for row in range(WorldGenerator.LAYOUT_ROWS):
		for col in range(1, last_col):
			var room := _add_room(load(layout[row][col]), Constants.COLUMNS * row + (col - 1), row, col)
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

func _add_room(scene: PackedScene, id: int, row: int, col: int) -> Room:
	var room: Room = scene.instantiate()
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
