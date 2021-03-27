extends Node2D

onready var goblin_death = $GoblinDeath
onready var knight_death = $KnightDeath

var player_active = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func death_sound(enemy_type):
	if(enemy_type == "Goblin"):
		goblin_death.play()
	elif(enemy_type == "Knight"):
		knight_death.play()
