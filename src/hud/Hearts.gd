extends HBoxContainer

var hearts = 3
var max_hearts = 3

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

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
