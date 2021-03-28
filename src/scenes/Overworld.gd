extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var rooms = []
var keyrooms = []
var start_room = "res://src/scenes/StartRoom.tscn"
var end_room = "res://src/scenes/EndRoom.tscn"

# Called when the node enters the scene tree for the first time.
func _ready():
	rooms()
	keyrooms()
	worldgen()
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
	var key_x = []
	for i in range(3):
		var rand = int(rand_range(1, 7))
		while (rand in key_x):
			rand = int(rand_range(1, 7))
		key_x.append(rand)
	
	var key_y = []
	for i in range(3):
		var rand = int(rand_range(0, 5))
		while (rand in key_y):
			rand = int(rand_range(0, 5))
		key_y.append(rand)
	
	var matrix = []
	for x in range(8):
		matrix.append([])
		for y in range(5):
			if (x == 0):
				if (y == 2):
					matrix[x].append(start_room)
				else:
					matrix[x].append('Null')
			elif(x == 7):
				if (y == 2):
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
