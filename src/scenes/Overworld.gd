extends Node2D

var matrix = []
var rooms = []
var keyrooms = []
var start_room = "res://src/scenes/StartRoom.tscn"
var end_room = "res://src/scenes/EndRoom.tscn"
var scenes = []

# Called when the node enters the scene tree for the first time.
func _ready():
	rooms()
	keyrooms()
	worldgen()
	doors()
	print(matrix)
	pass # Replace with function body.

func rooms():
	var numScenes = 0
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
				numScenes += 1
			file_name = dir.get_next()
#		print("Got a list of "+str(numScenes)+" files")

func keyrooms():
	var numScenes = 0
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
				numScenes += 1
			file_name = dir.get_next()
#		print("Got a list of "+str(numScenes)+" files")

func worldgen():
	var key_y = []
	for i in range(3):
		var rand = int(rand_range(1, 7))
		while (rand in key_y):
			rand = int(rand_range(1, 7))
		key_y.append(rand)
	
	var key_x = []
	for i in range(3):
		var rand = int(rand_range(0, 5))
		while (rand in key_x):
			rand = int(rand_range(0, 5))
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
	return scenes[int(rand_range(0, scenes.size()))]

func doors():
	for x in range(5):
		if(x == 2):
			continue
		for y in range(1, 7):
			if (x == 0):
				var node = scenes.get(matrix[x][y].substr(-7, 2)).instance
#continue work on doors, ^ will get the particular preloaded scene(all rooms will be preloaded at top) and instance it

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
