extends HBoxContainer

var hearts = 5
var max_hearts = 5

# Called when the node enters the scene tree for the first time.
func _ready():
	var hearts_save = File.new()
	if not hearts_save.file_exists("user://health.save"):
		print("Aborting, no savefile")
		return
	hearts_save.open("user://health.save", File.READ)
	max_hearts = int(hearts_save.get_line()) + 5
	hearts_save.close()
	
	hearts = max_hearts
	
	for heart in range (0, max_hearts):
		get_children()[heart].visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

#Changes the health based on the variable passed and returns how many hearts are left
func update_health(change):
	hearts = hearts + change
	
	for n in range (max_hearts):
		if(hearts >= n + 1):
			get_child(n).animation = "full"
		elif(hearts == n + 0.5):
			get_child(n).animation = "half"
		else:
			get_child(n).animation = "empty"
	
	return hearts


func _on_Timer_timeout():
	pass # Replace with function body.
