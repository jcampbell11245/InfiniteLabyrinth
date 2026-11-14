extends HBoxContainer

var hearts = 5
var max_hearts = 5

# Called when the node enters the scene tree for the first time.
func _ready():
	if not FileAccess.file_exists("user://health.save"):
		print("Aborting, no savefile")
		return
	var hearts_save = FileAccess.open("user://health.save", FileAccess.READ)
	max_hearts = int(hearts_save.get_line()) + 5
	hearts_save.close()
	
	hearts = max_hearts
	
	for heart in range (0, max_hearts):
		get_children()[heart].visible = true

#Changes the health based on the variable passed and returns how many hearts are left
func update_health(change):
	hearts = hearts + change
	
	for n in range (max_hearts):
		if(hearts >= n + 1):
			get_child(n).play("full")
		elif(hearts == n + 0.5):
			get_child(n).play("half")
		else:
			get_child(n).play("empty")
	
	return hearts
