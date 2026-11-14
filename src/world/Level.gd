extends Node2D

@onready var goblin_death = $GoblinDeath
@onready var knight_death = $KnightDeath
@onready var player = get_parent().get_node("Player")
@onready var animator = get_node("Void").get_node("Fade")

@export var completion_criteria = "none"
@export var enemy_count = 0
@export var room_id : int

var player_active = true
var locked = false
var faded_out = true
var doors = [true, true, true, true]

# Called when the node enters the scene tree for the first time.
func _ready():
	if(get_node_or_null("Decorations") != null):
		for x in range(9,17):
			for y in range(9, 17):
				if($Tiles.get_cell_source_id(0, Vector2i(x, y)) == 0 && $Pitfalls.get_cell_source_id(0, Vector2i(x, y)) == -1 && (get_node_or_null("Stalagmites") == null || $Stalagmites.get_cell_source_id(0, Vector2i(x, y)) == -1)):
					var rng = RandomNumberGenerator.new()
					rng.randomize()
					var variant = rng.randi_range(0, 66)
					if(variant > 58):
						if(variant < 60):
							$Decorations.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						if(variant < 64):
							$Decorations.set_cell(0, Vector2i(x, y), 1, Vector2i.ZERO)
						if(variant < 66):
							$Decorations.set_cell(0, Vector2i(x, y), 2, Vector2i.ZERO)
						else:
							$Decorations.set_cell(0, Vector2i(x, y), 3, Vector2i.ZERO)

	for x in range(10,17):
		for y in range(10, 17):
			if($Tiles.get_cell_source_id(0, Vector2i(x, y)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(x, y)) == 4):
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var variant = rng.randi_range(0, 2)
				$Tiles.set_cell(0, Vector2i(x, y), 32 + variant, Vector2i.ZERO)
	
	for x in range(10,17):
		if($Tiles.get_cell_source_id(0, Vector2i(x, 9)) == 0) || $Tiles.get_cell_source_id(0, Vector2i(x, 9)) == 4:
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(0, Vector2i(x, 9), 39 + variant, Vector2i.ZERO)
	
	for x in range(10,17):
		if($Tiles.get_cell_source_id(0, Vector2i(x, 17)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(x, 17)) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(0, Vector2i(x, 17), 28 + variant, Vector2i.ZERO)
	
	for y in range(10,17):
		if($Tiles.get_cell_source_id(0, Vector2i(9, y)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(9, y)) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(0, Vector2i(9, y), 30 + variant, Vector2i.ZERO)
	
	for y in range(10,17):
		if($Tiles.get_cell_source_id(0, Vector2i(17, y)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(17, y)) == 4):
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			var variant = rng.randi_range(0, 1)
			$Tiles.set_cell(0, Vector2i(17, y), 37 + variant, Vector2i.ZERO)
	
	if($Tiles.get_cell_source_id(0, Vector2i(9, 9)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(9, 9)) == 4):
		$Tiles.set_cell(0, Vector2i(9, 9), 35, Vector2i.ZERO)
	
	if($Tiles.get_cell_source_id(0, Vector2i(17, 9)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(17, 9)) == 4):
		$Tiles.set_cell(0, Vector2i(17, 9), 36, Vector2i.ZERO)
	
	if($Tiles.get_cell_source_id(0, Vector2i(9, 17)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(9, 17)) == 4):
		$Tiles.set_cell(0, Vector2i(9, 17), 26, Vector2i.ZERO)
	
	if($Tiles.get_cell_source_id(0, Vector2i(17, 17)) == 0 || $Tiles.get_cell_source_id(0, Vector2i(17, 17)) == 4):
		$Tiles.set_cell(0, Vector2i(17, 17), 27, Vector2i.ZERO)
	
	#Sets pitfall transitions
	if(get_node_or_null("PitfallTransitions") != null):
		for x in range(9,18):
			for y in range(9, 18):
				if($Pitfalls.get_cell_source_id(0, Vector2i(x, y)) != -1):
					var top = $Pitfalls.get_cell_source_id(0, Vector2i(x, y - 1)) == -1
					var right = $Pitfalls.get_cell_source_id(0, Vector2i(x + 1, y)) == -1
					var bottom = $Pitfalls.get_cell_source_id(0, Vector2i(x, y + 1)) == -1
					var left = $Pitfalls.get_cell_source_id(0, Vector2i(x - 1, y)) == -1
					
					if(top):
						$PitfallTransitions.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						$PitfallTransitions.z_index = -1
					if(right):
						var tileset = load("res://src/world/tiles/PitfallTransitionsR.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					if(bottom):
						var tileset = load("res://src/world/tiles/PitfallTransitionsB.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					if(left):
						var tileset = load("res://src/world/tiles/PitfallTransitionsL.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					
					if(top && right):
						var tileset = load("res://src/world/tiles/PitfallTransitionsTR.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					if(bottom && right):
						var tileset = load("res://src/world/tiles/PitfallTransitionsBR.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					if(bottom && left):
						var tileset = load("res://src/world/tiles/PitfallTransitionsBL.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
					if(top && left):
						var tileset = load("res://src/world/tiles/PitfallTransitionsTL.tscn").instantiate()
						tileset.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
						tileset.z_index = -1
						add_child(tileset)
	
	#Sets pitfall spike decorations
	if(get_node_or_null("Pitfalls") != null):
		var spikes = load("res://src/world/tiles/PitfallSpikes.tscn").instantiate()
		var rng = RandomNumberGenerator.new()
		
		for x in range(9,17):
			for y in range(9, 17):
				if($Pitfalls.get_cell_source_id(0, Vector2i(x, y)) != -1):
					rng.randomize()
					var variant = rng.randi_range(0, 3)
					
					if(variant == 0):
						spikes.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO)
		
		add_child(spikes)
	
	#Sets transition detection zones
	var detectors = load("res://src/world/tiles/TransitionDetector.tscn").instantiate()
	
	if($Tiles.get_cell_source_id(0, Vector2i(13, 8)) == 1 || 20 || 21):
		detectors.set_cell(0, Vector2i(13, 8), 0, Vector2i.ZERO)
	if($Top.get_cell_source_id(0, Vector2i(18, 13)) == 8 || (get_node_or_null("Locks") != null && $Locks.get_cell_source_id(0, Vector2i(18, 13)) == 2 || 3)):
		detectors.set_cell(0, Vector2i(18, 13), 0, Vector2i.ZERO)
	if($Top.get_cell_source_id(0, Vector2i(13, 18)) == 13):
		detectors.set_cell(0, Vector2i(13, 18), 0, Vector2i.ZERO)
	if($Top.get_cell_source_id(0, Vector2i(8, 13)) == 5 || (get_node_or_null("Locks") != null && $Locks.get_cell_source_id(0, Vector2i(18, 13)) == 0 || 1)):
		detectors.set_cell(0, Vector2i(8, 13), 0, Vector2i.ZERO)
	
	add_child(detectors)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#Set doors
	if(!doors[0] && room_id != 61):
		$Tiles.set_cell(0, Vector2i(13, 8), 6, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(13, 8), 3, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(13, 7), 1, Vector2i.ZERO)
	if(!doors[1]):
		$Top.set_cell(0, Vector2i(18, 13), 12, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(18, 12), 12, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(18, 11), 12, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(18, 13), 10, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(18, 12), 10, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(18, 11), 10, Vector2i.ZERO)
	if(!doors[2]):
		$Tiles.set_cell(0, Vector2i(13, 18), 5, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(13, 18), 3, Vector2i.ZERO)
	if(!doors[3]):
		$Top.set_cell(0, Vector2i(8, 13), 4, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(8, 12), 4, Vector2i.ZERO)
		$Top.set_cell(0, Vector2i(8, 11), 4, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(8, 13), 7, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(8, 12), 7, Vector2i.ZERO)
		$Tiles.set_cell(0, Vector2i(8, 11), 7, Vector2i.ZERO)
		
	if(room_id == 61):
		if(get_parent().get_node("CameraRig/Camera2D/HudLayer/Hud/Keys").get_keys() == 3):
			$Tiles.set_cell(0, Vector2i(13, 8), 1, Vector2i.ZERO)
	
	#Fade in/out
	if(player.current_room != room_id && !faded_out):
		animator.play("FadeOut")
		faded_out = true
	elif(player.current_room == room_id && faded_out):
		animator.play("FadeIn")
		faded_out = false
	
	if(!locked && player.current_room == room_id && get_node_or_null("Locks") != null):
		locked = true
		if(completion_criteria == "switches"):
			$Tiles.set_cell(0, Vector2i(13, 8), 21, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 13), 1, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 12), 5, Vector2i.ZERO)
			$Tiles.set_cell(0, Vector2i(13, 18), 18, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 13), 2, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 12), 6, Vector2i.ZERO)
		elif(completion_criteria == "enemies"):
			$Tiles.set_cell(0, Vector2i(13, 8), 20, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 13), 0, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 12), 4, Vector2i.ZERO)
			$Tiles.set_cell(0, Vector2i(13, 18), 18, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 13), 3, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 12), 7, Vector2i.ZERO)
	
	if(completion_criteria == "switches" && $Switches.unlocked()):
		if(doors[0]):
			$Tiles.set_cell(0, Vector2i(13, 8), 1, Vector2i.ZERO)
		if(doors[3]):
			$Locks.set_cell(0, Vector2i(8, 13), 8, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 12), 8, Vector2i.ZERO)
		if(doors[2]):
			$Tiles.set_cell(0, Vector2i(13, 18), 16, Vector2i.ZERO)
		if(doors[1]):
			$Locks.set_cell(0, Vector2i(18, 13), 8, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 12), 8, Vector2i.ZERO)
	elif(completion_criteria == "enemies" && enemy_count == 0):
		if(doors[0]):
			$Tiles.set_cell(0, Vector2i(13, 8), 1, Vector2i.ZERO)
		if(doors[3]):
			$Locks.set_cell(0, Vector2i(8, 13), 8, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(8, 12), 8, Vector2i.ZERO)
		if(doors[2]):
			$Tiles.set_cell(0, Vector2i(13, 18), 16, Vector2i.ZERO)
		if(doors[1]):
			$Locks.set_cell(0, Vector2i(18, 13), 8, Vector2i.ZERO)
			$Locks.set_cell(0, Vector2i(18, 12), 8, Vector2i.ZERO)

func death_sound(enemy_type):
	if(enemy_type == "Goblin"):
		goblin_death.play()
	elif(enemy_type == "Knight"):
		knight_death.play()

func _on_next_floor_area_entered(area):
	get_parent().get_node("CameraRig/Camera2D/UpgradeMenu/Control").show_menu()

func _on_boss_door_animation_finished():
	if($BossDoor.animation == "opening"):
		player.transition()
