extends HBoxContainer

# Shows the player's health as a row of hearts, one per point of max health. Each child is
# a heart sprite with "full", "half" and "empty" animations.

var max_hearts = 0

func _ready():
	Game.health_changed.connect(_show)
	max_hearts = SaveData.health_level + Constants.BASE_HEALTH
	for heart in range(max_hearts):
		get_child(heart).visible = true

func _show(health):
	for n in range(max_hearts):
		if(health >= n + 1):
			get_child(n).play("full")
		elif(health == n + 0.5):
			get_child(n).play("half")
		else:
			get_child(n).play("empty")
