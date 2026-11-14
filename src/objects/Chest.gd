extends Node2D

var open = false
@export var direction = "down"
@onready var keys = get_parent().get_parent().get_node("CameraRig/Camera2D/HudLayer/Hud/Keys")

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimatedSprite2D.animation = "closed_" + direction

func _on_area_2d_area_entered(area):
	if((area.get_name() == "Hitbox") && !open):
		$Open.play()
		open = true
		$AnimatedSprite2D.animation = "open_" + direction
		keys.add_keys(1)
