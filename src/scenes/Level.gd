extends Node2D

onready var goblin_death = $GoblinDeath
onready var knight_death = $KnightDeath
onready var player = get_parent().get_node("Player2D")
onready var animator = get_node("Void").get_node("Fade")

export var completion_criteria = "none"
export var enemy_count = 0
export var room_id : int

var player_active = true
var locked = false
var faded_out = true
var doors = [true, true, true, true]

# Called when the node enters the scene tree for the first time.
#func _ready():

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#Set doors
	if(!doors[0] && room_id != 61):
		$Tiles.set_cell(13, 8, 6)
		$Top.set_cell(13, 7, 1)
	if(!doors[1]):
		$Tiles.set_cell(18, 13, 0)
		$TopWalls.set_cell(18, 13, 1)
	if(!doors[2]):
		$Tiles.set_cell(13, 18, 5)
	if(!doors[3]):
		$Tiles.set_cell(8, 13, 0)
		$TopWalls.set_cell(8, 13, 0)
		
	if(room_id == 61):
		if(get_parent().get_node("CameraHolder/Camera2D/HudLayer/Hud/Keys").get_keys() == 3):
			$Tiles.set_cell(13, 8, 1)
	
	#Fade in/out
	if(player.current_room != room_id && !faded_out):
		animator.play("FadeOut")
		faded_out = true
	elif(player.current_room == room_id && faded_out):
		animator.play("FadeIn")
		faded_out = false
	
	if(!locked && player.current_room == room_id):
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
		if(doors[0]):
			$Tiles.set_cell(13, 8, 1)
		if(doors[3]):
			$Tiles.set_cell(8, 13, 16)
		if(doors[2]):
			$Tiles.set_cell(13, 18, 16)
		if(doors[1]):
			$Tiles.set_cell(18, 13, 16)
	elif(completion_criteria == "enemies" && enemy_count == 0):
		if(doors[0]):
			$Tiles.set_cell(13, 8, 1)
		if(doors[3]):
			$Tiles.set_cell(8, 13, 16)
		if(doors[2]):
			$Tiles.set_cell(13, 18, 16)
		if(doors[1]):
			$Tiles.set_cell(18, 13, 16)

func death_sound(enemy_type):
	if(enemy_type == "Goblin"):
		goblin_death.play()
	elif(enemy_type == "Knight"):
		knight_death.play()


func _on_NextFloor_area_entered(area):
	get_parent().get_node("CameraHolder/Camera2D/UpgradeMenu/Control").show_menu()
