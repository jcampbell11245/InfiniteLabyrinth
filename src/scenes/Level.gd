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
func _ready():
	#Set stalagmites
	#if($Stalagmites != null):
	#	for x in range(9,18):
	#		for y in range(9, 10):
	#			if($Stalagmites.get_cell(x, y - 1) != -1):
	#					fileName += "_t"
	#				if($Stalagmites.get_cell(x - 1, y) != -1):
	#					fileName += "_l"
	#				if($Stalagmites.get_cell(x + 1, y) != -1):
	#					fileName += "_r"
	#				if($Stalagmites.get_cell(x, y + 1) != -1):
	#					fileName += "_b"
	#				
	#				var tile_id
	#				match fileName:
	#					"stalagmites":
	#						tile_id = 0
	#					"stalagmites_b":
	#						tile_id = 1
	#					"stalagmites_l":
	#						tile_id = 2
	#					"stalagmites_l_b":
	#						tile_id = 3
	#					"stalagmites_l_r":
	#						tile_id = 4
	#					"stalagmites_l_r_b":
	#						tile_id = 5
	#					"stalagmites_r":
	#						tile_id = 6
	#					"stalagmites_r_b":
	#						tile_id = 7
	#					"stalagmites_t":
	#						tile_id = 8
	#					"stalagmites_t_b":
	#						tile_id = 9
	#					"stalagmites_t_l":
	#						tile_id = 10
	#					"stalagmites_t_l_b":
	#						tile_id = 11
	#					"stalagmites_t_l_r":
	#						tile_id = 12
	#					"stalagmites_t_l_r_b":
	#						tile_id = 13
	#					"stalagmites_t_r":
	#						tile_id = 14
	#					"stalagmites_t_r_b":
	#						tile_id = 15
	#				
	#				$Stalagmites.set_cell(x, y, tile_id)

	if($Decorations != null):
		for x in range(9,17):
			for y in range(9, 17):
				if($Tiles.get_cell(x, y) == 0 && $Pitfalls.get_cell(x, y) == -1 && ($Stalagmites == null || $Stalagmites.get_cell(x, y) == -1)):
					var rng = RandomNumberGenerator.new()
					rng.randomize()
					var variant = rng.randi_range(0, 66)
					if(variant > 58):
						if(variant < 60):
							$Decorations.set_cell(x, y, 0)
						if(variant < 64):
							$Decorations.set_cell(x, y, 1)
						if(variant < 66):
							$Decorations.set_cell(x, y, 2)
						else:
							$Decorations.set_cell(x, y, 3)

	for x in range(10,17):
		for y in range(10, 17):
			if($Tiles.get_cell(x, y) == 0 || $Tiles.get_cell(x, y) == 4):
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var variant = rng.randi_range(0, 2)
				$Tiles.set_cell(x, y, 32 + variant)
	
	for x in range(10,17):
		if($Tiles.get_cell(x, 9) == 0) || $Tiles.get_cell(x, 9) == 4:
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(x, 9, 39 + variant)
	
	for x in range(10,17):
		if($Tiles.get_cell(x, 17) == 0 || $Tiles.get_cell(x, 17) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(x, 17, 28 + variant)
	
	for y in range(10,17):
		if($Tiles.get_cell(9, y) == 0 || $Tiles.get_cell(9, y) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(9, y, 30 + variant)
	
	for y in range(10,17):
		if($Tiles.get_cell(17, y) == 0 || $Tiles.get_cell(17, y) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(17, y, 37 + variant)
	
	if($Tiles.get_cell(9, 9) == 0 || $Tiles.get_cell(9, 9) == 4):
		$Tiles.set_cell(9, 9, 35)
	
	if($Tiles.get_cell(17, 9) == 0 || $Tiles.get_cell(17, 9) == 4):
		$Tiles.set_cell(17, 9, 36)
	
	if($Tiles.get_cell(9, 17) == 0 || $Tiles.get_cell(9, 17) == 4):
		$Tiles.set_cell(9, 17, 26)
	
	if($Tiles.get_cell(17, 17) == 0 || $Tiles.get_cell(17, 17) == 4):
		$Tiles.set_cell(17, 17, 27)
	
	#Sets pitfall transitions
	if($PitfallTransitions != null):
		for x in range(9,17):
			for y in range(9, 17):
				if($Pitfalls.get_cell(x, y) != -1):
					var top = $Pitfalls.get_cell(x, y - 1) == -1
					var right = $Pitfalls.get_cell(x + 1, y) == -1
					var bottom = $Pitfalls.get_cell(x, y + 1) == -1
					var left = $Pitfalls.get_cell(x - 1, y) == -1
					
					if(top && right):
						$PitfallTransitions.set_cell(x, y, 4)
					elif(top && left):
						$PitfallTransitions.set_cell(x, y, 4)
					elif(bottom && right):
						$PitfallTransitions.set_cell(x, y, 4)
					elif(bottom && left):
						$PitfallTransitions.set_cell(x, y, 4)
					elif(top):
						$PitfallTransitions.set_cell(x, y, 0)
					elif(right):
						$PitfallTransitions.set_cell(x, y, 1)
					elif(bottom):
						$PitfallTransitions.set_cell(x, y, 2)
					elif(left):
						$PitfallTransitions.set_cell(x, y, 3)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#Set doors
	if(!doors[0] && room_id != 61):
		$Tiles.set_cell(13, 8, 6)
		$Top.set_cell(13, 8, 3)
		$Top.set_cell(13, 7, 1)
	if(!doors[1]):
		$Top.set_cell(18, 13, 13)
		$Top.set_cell(18, 12, 13)
		$Top.set_cell(18, 11, 13)
		$Tiles.set_cell(18, 13, 10)
		$Tiles.set_cell(18, 12, 10)
		$Tiles.set_cell(18, 11, 10)
	if(!doors[2]):
		$Tiles.set_cell(13, 18, 5)
		$Top.set_cell(13, 18, 3)
	if(!doors[3]):
		$Top.set_cell(8, 13, 4)
		$Top.set_cell(8, 12, 4)
		$Top.set_cell(8, 11, 4)
		$Tiles.set_cell(8, 13, 7)
		$Tiles.set_cell(8, 12, 7)
		$Tiles.set_cell(8, 11, 7)
		
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
	
	if(!locked && player.current_room == room_id && $Locks != null):
		locked = true
		if(completion_criteria == "switches"):
			$Tiles.set_cell(13, 8, 21)
			$Locks.set_cell(8, 13, 1)
			$Locks.set_cell(8, 12, 5)
			$Tiles.set_cell(13, 18, 18)
			$Locks.set_cell(18, 13, 2)
			$Locks.set_cell(18, 12, 6)
		elif(completion_criteria == "enemies"):
			$Tiles.set_cell(13, 8, 20)
			$Locks.set_cell(8, 13, 0)
			$Locks.set_cell(8, 12, 4)
			$Tiles.set_cell(13, 18, 18)
			$Locks.set_cell(18, 13, 3)
			$Locks.set_cell(18, 12, 7)
	
	if(completion_criteria == "switches" && $Switches.unlocked()):
		if(doors[0]):
			$Tiles.set_cell(13, 8, 1)
		if(doors[3]):
			$Locks.set_cell(8, 13, 8)
			$Locks.set_cell(8, 12, 8)
		if(doors[2]):
			$Tiles.set_cell(13, 18, 16)
		if(doors[1]):
			$Locks.set_cell(18, 13, 8)
			$Locks.set_cell(18, 12, 8)
	elif(completion_criteria == "enemies" && enemy_count == 0):
		if(doors[0]):
			$Tiles.set_cell(13, 8, 1)
		if(doors[3]):
			$Locks.set_cell(8, 13, 8)
			$Locks.set_cell(8, 12, 8)
		if(doors[2]):
			$Tiles.set_cell(13, 18, 16)
		if(doors[1]):
			$Locks.set_cell(18, 13, 8)
			$Locks.set_cell(18, 12, 8)

func death_sound(enemy_type):
	if(enemy_type == "Goblin"):
		goblin_death.play()
	elif(enemy_type == "Knight"):
		knight_death.play()


func _on_NextFloor_area_entered(area):
	get_parent().get_node("CameraHolder/Camera2D/UpgradeMenu/Control").show_menu()
