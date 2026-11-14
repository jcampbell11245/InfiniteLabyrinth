extends Node2D

#264x288

@onready var matrix = []

var rng = RandomNumberGenerator.new()
var rooms = []
var keyrooms = []
var start_room = "res://src/world/special/StartRoom.tscn"
var end_room = "res://src/world/special/EndRoom.tscn"
var floor_number
@export var columns = 6

# Called when the node enters the scene tree for the first time.
func _ready():
	load_coins()
	if not FileAccess.file_exists("user://floor.save"):
		print("Aborting, no savefile")
		return

	var floor_save = FileAccess.open("user://floor.save", FileAccess.READ)
	floor_number = int(floor_save.get_line())
	floor_save.close()
	
	load_rooms()
	load_keyrooms()
	worldgen()
	doors()

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
	start.position = Vector2(0-191, 288*2-168)
	start.room_id = 60
	start.doors[0] = false
	start.doors[2] = false
	
	var broom = load("res://src/world/special/BossRoom.tscn").instantiate()
	add_child(broom)
	broom.position = Vector2(-264-191, 288*2-168)
	broom.room_id = 62
	broom.doors[0] = false
	broom.doors[2] = false
	broom.doors[3] = false

	var end = load(matrix[2][7]).instantiate()
	add_child(end)
	end.position = Vector2(264*7-191, 288*2-168)
	end.room_id = 61
	end.doors[0] = false
	end.doors[1] = false
	end.doors[2] = false
	
	for x in range(5):
		for y in range(1, 7):
			var room = load(matrix[x][y]).instantiate()
			add_child(room)
			room.position = Vector2(264*y-191, 288*x-168)
			room.room_id = 6 * x + (y - 1)
			
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

func reset_world():
	save_coins()
	get_tree().change_scene_to_file("res://src/world/Overworld.tscn")

func load_coins():
	print("Loading...")

	if not FileAccess.file_exists("user://savefile.save"):
		print("Aborting, no savefile")
		return

	var save_file = FileAccess.open("user://savefile.save", FileAccess.READ)
	get_child(1).get_node("Camera2D/HudLayer/Hud/Coins").coins = int(save_file.get_line())
	get_child(1).get_node("Camera2D/HudLayer/Hud/Coins").update_text()
	save_file.close()

func save_coins():
	print("Saving...")

	var save_file = FileAccess.open("user://savefile.save", FileAccess.WRITE)
	save_file.store_line(str(get_child(1).get_node("Camera2D/HudLayer/Hud/Coins").coins))
	save_file.close()
