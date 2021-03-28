extends Node2D

#264x288

onready var matrix = []

var rng = RandomNumberGenerator.new()
var rooms = []
var keyrooms = []
var start_room = "res://src/scenes/StartRoom.tscn"
var end_room = "res://src/scenes/EndRoom.tscn"
export var columns = 6

# Called when the node enters the scene tree for the first time.
func _ready():
	rooms()
	keyrooms()
	worldgen()
	roomspawn()
#	doors()

#	print(matrix)

func rooms():
	var _numScenes = 0
	var dir = Directory.new()
	if dir.open("res://src/scenes/rooms/") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
#			print(file_name)
			if file_name == ".." or file_name == ".":
				# Directories, Skip.
				pass
			else:
				rooms.push_back("res://src/scenes/rooms/"+file_name)
				_numScenes += 1
			file_name = dir.get_next()
#		print("Got a list of "+str(numScenes)+" files")

func keyrooms():
	var _numScenes = 0
	var dir = Directory.new()
	if dir.open("res://src/scenes/keyrooms/") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
#			print(file_name)
			if file_name == ".." or file_name == ".":
				# Directories, Skip.
				pass
			else:
				keyrooms.push_back("res://src/scenes/keyrooms/"+file_name)
				_numScenes += 1
			file_name = dir.get_next()
#		print("Got a list of "+str(numScenes)+" files")

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
				matrix[x].append(randomscene(keyrooms))
			elif(x == key_x[1] and y == key_y[1]):
				matrix[x].append(randomscene(keyrooms))
			elif(x == key_x[2] and y == key_y[2]):
				matrix[x].append(randomscene(keyrooms))
			else:
				matrix[x].append(randomscene(rooms))
			print(matrix[x][y])

func randomscene(var scenes):
	return scenes[int(rng.randi_range(0, scenes.size()-1))]

func doors():
	for x in range(5):
		if(x == 2):
			continue
		for y in range(1, 7):
			var room = load(matrix[x][y]).instance()
			if(x == 0):
				room.doors[0] = false
			elif(x == 4):
				room.doors[2] = false
			if(y == 1):
				room.doors[3] = false
			elif(y == 6):
				room.doors[1] = false

func roomspawn():
	print(matrix[2][0])
	var start = load(matrix[2][0]).instance()
	add_child(start)
	start.position = Vector2(0, 288*2)
	
	var end = load(matrix[2][7]).instance()
	add_child(end)
	end.position = Vector2(264*7, 288*2)
	
	for x in range(5):
		for y in range(1, 7):
			var room = load(matrix[x][y]).instance()
			add_child(room)
			room.position = Vector2(264*y, 288*x)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
