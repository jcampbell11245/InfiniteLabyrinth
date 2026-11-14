extends HBoxContainer

var hearts = 5
var max_hearts = 5

func _ready():
	max_hearts = SaveData.health_level + 5
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
