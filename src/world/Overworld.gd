extends Node2D

# Top-left offset of the room grid; a room at (row, col) sits at GRID_ORIGIN + ROOM_SIZE * (col, row).
# Column 0 holds the start room, columns 1..COLUMNS the generated rooms, then the end room.
const GRID_ORIGIN = Vector2(-191, -168)

@onready var matrix = []

var rng = RandomNumberGenerator.new()
var rooms = []
var keyrooms = []
var start_room = "res://src/world/special/StartRoom.tscn"
var end_room = "res://src/world/special/EndRoom.tscn"
var floor_number
var rooms_by_id = {}

func _enter_tree():
	Game.register(self)

func _exit_tree():
	Game.unregister(self)

func _ready():
	Game.coins.coins = SaveData.coins
	Game.coins.update_text()
	floor_number = SaveData.floor_number
	
	load_rooms()
	load_keyrooms()
	worldgen()
	doors()
	
	Music.start_floor()
	Game.player.boss_door_reached.connect(_on_player_boss_door_reached)
	Game.player.transition_pause_finished.connect(_on_player_transition_pause_finished)
	rooms_by_id[Constants.BOSS_ROOM].get_node("BossDoorBody/BossDoorClose").finished.connect(_on_boss_door_closed)

func load_rooms():
	for file_name in ResourceLoader.list_directory("res://src/world/rooms/"):
		if file_name.ends_with(".tscn"):
			rooms.push_back("res://src/world/rooms/"+file_name)

func load_keyrooms():
	for file_name in ResourceLoader.list_directory("res://src/world/keyrooms/"):
		if file_name.ends_with(".tscn"):
			keyrooms.push_back("res://src/world/keyrooms/"+file_name)

func worldgen():
	rng.randomize()
	
	var key_y = []
	for _i in range(3):
		var rand = int(rng.randi_range(1, 6))
		while (rand in key_y):
			rand = int(rng.randi_range(1, 6))
		key_y.append(rand)
	
	var key_x = []
	for _i in range(3):
		var rand = int(rng.randi_range(0, 4))
		while (rand in key_x):
			rand = int(rng.randi_range(0, 4))
		key_x.append(rand)
	
	for x in range(5):
		matrix.append([])
		for y in range(8):
			if (y == 0):
				if (x == 2):
					matrix[x].append(start_room)
				else:
					matrix[x].append('Null')
			elif(y == 7):
				if (x == 2):
					matrix[x].append(end_room)
				else:
					matrix[x].append('Null')
			elif(x == key_x[0] and y == key_y[0]):
				matrix[x].append(keyrooms[0])
			elif(x == key_x[1] and y == key_y[1]):
				matrix[x].append(keyrooms[1])
			elif(x == key_x[2] and y == key_y[2]):
				matrix[x].append(keyrooms[2])
			else:
				matrix[x].append(randomscene(rooms))

func randomscene(scenes):
	var room = scenes[int(rng.randi_range(0, scenes.size()-1))]
	scenes.erase(room)
	return room

func doors():
	var start = load(matrix[2][0]).instantiate()
	add_child(start)
	start.position = grid_position(2, 0)
	start.room_id = Constants.START_ROOM
	rooms_by_id[start.room_id] = start
	start.doors[0] = false
	start.doors[2] = false
	
	var broom = load("res://src/world/special/BossRoom.tscn").instantiate()
	add_child(broom)
	broom.position = grid_position(2, -1)
	broom.room_id = Constants.BOSS_ROOM
	rooms_by_id[broom.room_id] = broom
	broom.doors[0] = false
	broom.doors[2] = false
	broom.doors[3] = false

	var end = load(matrix[2][7]).instantiate()
	add_child(end)
	end.position = grid_position(2, 7)
	end.room_id = Constants.END_ROOM
	rooms_by_id[end.room_id] = end
	end.doors[0] = false
	end.doors[1] = false
	end.doors[2] = false
	
	for x in range(5):
		for y in range(1, 7):
			var room = load(matrix[x][y]).instantiate()
			add_child(room)
			room.position = grid_position(x, y)
			room.room_id = Constants.COLUMNS * x + (y - 1)
			rooms_by_id[room.room_id] = room
			
			if(x == 2):
				continue
			
			if(x == 0):
				room.doors[0] = false
			elif(x == 4):
				room.doors[2] = false
			
			if(y == 1):
				room.doors[3] = false
			elif(y == 6):
				room.doors[1] = false

func grid_position(row, col):
	return GRID_ORIGIN + Constants.ROOM_SIZE * Vector2(col, row)

# Boss door sequence: the player steps on the start room's trigger, the door opens and the
# player walks through (StartRoom calls player.start_transition() once it's open). When the
# transition pause ends in the boss room, the door slams shut and the boss music starts.
func _on_player_boss_door_reached():
	var start = rooms_by_id[Constants.START_ROOM]
	Music.stop_dungeon()
	start.get_node("BossDoor/BossDoorOpen").play()
	Game.camera.shake(3.7, 20, 1)
	start.get_node("BossDoor").play("opening")

func _on_player_transition_pause_finished():
	if(Game.player.current_room == Constants.BOSS_ROOM && !Music.is_boss_playing()):
		var door = rooms_by_id[Constants.BOSS_ROOM].get_node("BossDoorBody")
		door.get_node("BossDoorClose").play()
		door.get_node("BossDoor").play("closing")
		door.get_node("CollisionShape2D").disabled = false
	else:
		Game.player.end_transition()

func _on_boss_door_closed():
	Game.player.end_transition()
	Music.play_boss()

func reset_world():
	SaveData.coins = Game.coins.coins
	SaveData.save()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")
