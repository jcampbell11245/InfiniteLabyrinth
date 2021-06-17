extends Node2D

var open = false
export var direction = "down"
onready var keys = get_parent().get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Keys")

# Called when the node enters the scene tree for the first time.
func _ready():
	$AnimatedSprite.animation = "closed_" + direction


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Area2D_area_entered(area):
	if((area.get_name() == "Hitbox") && !open):
		$Open.play()
		open = true
		$AnimatedSprite.animation = "open_" + direction
		keys.add_keys(1)
