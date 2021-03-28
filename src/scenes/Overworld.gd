extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	worldgen()
	pass # Replace with function body.

func worldgen():
	var matrix = []
	for x in range(3):
		matrix.append([])
		for y in range(3):
			matrix[x].append(randomscene())

func randomscene():
	var numScenes = 0
	var dir = Directory.new()
	if dir.open("res://src/scenes/rooms/") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while (file_name != ""):
			print(file_name)
			if file_name == ".." or file_name == ".":
				# Directories, Skip.
				pass
			else:
				paths.push_back("res://src/scenes/rooms/"+file_name+"/scn.tscn")
			if dir.current_is_dir():
				numScenes += 1
			file_name = dir.get_next()
		print("Got a list of "+str(numScenes)+" files")
	
	var random_scene = dir[int(rand_range(0, dir.size()))]

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
