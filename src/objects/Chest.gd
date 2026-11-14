extends Node2D

var open = false
@export var direction = "down"

func _ready():
	$AnimatedSprite2D.animation = "closed_" + direction

func _on_area_2d_area_entered(area):
	if((area.get_name() == "Hitbox") && !open):
		$Open.play()
		open = true
		$AnimatedSprite2D.animation = "open_" + direction
		Game.keys.add_keys(1)
