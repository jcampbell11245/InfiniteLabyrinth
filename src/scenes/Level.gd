extends Node2D

onready var goblin_death = $GoblinDeath
onready var knight_death = $KnightDeath

export var completion_criteria = "none"
export var enemy_count = 0

var player_active = true

# Called when the node enters the scene tree for the first time.
func _ready():
	if(completion_criteria == "switches"):
		$Tiles.set_cell(13, 8, 18)
		$Tiles.set_cell(8, 13, 18)
		$Tiles.set_cell(13, 18, 18)
		$Tiles.set_cell(18, 13, 18)
	elif(completion_criteria == "enemies"):
		$Tiles.set_cell(13, 8, 19)
		$Tiles.set_cell(8, 13, 19)
		$Tiles.set_cell(13, 18, 19)
		$Tiles.set_cell(18, 13, 19)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
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
