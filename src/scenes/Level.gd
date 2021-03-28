extends Node2D

onready var goblin_death = $GoblinDeath
onready var knight_death = $KnightDeath

export var completion_criteria = "none"
export var enemy_count = 0
export var room_id : int

var player_active = true
var locked = false

# Called when the node enters the scene tree for the first time.
#func _ready():

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(!locked && get_parent().get_node("Player2D").current_room == room_id):
		locked = true
		if(completion_criteria == "switches"):
			$Tiles.set_cell(13, 8, 21)
			$Tiles.set_cell(8, 13, 23)
			$Tiles.set_cell(13, 18, 18)
			$Tiles.set_cell(18, 13, 25)
		elif(completion_criteria == "enemies"):
			$Tiles.set_cell(13, 8, 20)
			$Tiles.set_cell(8, 13, 22)
			$Tiles.set_cell(13, 18, 19)
			$Tiles.set_cell(18, 13, 24)
	
	if(completion_criteria == "switches" && $Switches.unlocked()):
		$Tiles.set_cell(13, 8, 1)
		$Tiles.set_cell(8, 13, 16)
		$Tiles.set_cell(13, 18, 16)
		$Tiles.set_cell(18, 13, 16)
	elif(completion_criteria == "enemies" && enemy_count == 0):
		$Tiles.set_cell(13, 8, 1)
		$Tiles.set_cell(8, 13, 16)
		$Tiles.set_cell(13, 18, 16)
		$Tiles.set_cell(18, 13, 16)

func death_sound(enemy_type):
	if(enemy_type == "Goblin"):
		goblin_death.play()
	elif(enemy_type == "Knight"):
		knight_death.play()
