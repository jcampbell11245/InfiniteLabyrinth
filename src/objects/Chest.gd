extends Node2D

# Key chest: opens and gives a key the first time the player's sword hits it.

@export var direction := "down" # Which way the chest faces, an animation suffix

var open := false

func _ready() -> void:
	$AnimatedSprite2D.animation = "closed_" + direction

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_name() == "Hitbox" && !open:
		$Open.play()
		open = true
		$AnimatedSprite2D.animation = "open_" + direction
		Game.add_keys(1)
