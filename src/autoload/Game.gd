extends Node

# Game-wide state and signals for the running floor, plus references to the long-lived
# nodes of the Overworld so other scripts don't have to walk the scene tree to find them.
# Overworld registers itself when it enters the tree.

signal room_entered(room_id: int) # The player walked into a room
signal coins_changed(coins: int)
signal keys_changed(keys: int)
signal arrows_changed(arrows: int)
signal arrows_empty # Tried to shoot with no arrows left
signal time_lost(seconds: float, fatal: bool) # Taken off the level timer by damage
signal fatal_countdown_finished # The timer has shown a killing hit draining it to 0:00
signal player_died
signal item_selected(slot: int) # The highlighted box on the item bar moved
signal item_used(slot: int) # The use-item button was pressed on that slot

var coins := 0 # Banked into SaveData when the floor ends
var keys := 0 # Held now; Tuning.keys_to_finish open the end room
# Spare keys from the floor just finished, added to the next floor's when it starts. Only
# set between finishing a floor and the next one starting, so a death or a new run gets none.
var carried_keys := 0
var arrows := 0 # Left to shoot; refilled to Tuning.start_arrows each floor
var item_slot := 0 # Highlighted box on the item bar, 0 to Tuning.item_slots - 1

# Keys given at the start of each floor and the floor a new run starts on are
# Tuning.start_keys and Tuning.start_floor (debug menu, F2).

var overworld: Overworld
var player: Player
var camera_rig: CharacterBody2D
var camera: ShakeCamera
var upgrade_menu: UpgradeMenu

func register(world: Overworld) -> void:
	overworld = world
	player = world.get_node("Player")
	camera_rig = world.get_node("CameraRig")
	camera = camera_rig.get_node("Camera2D")
	upgrade_menu = camera.get_node("UpgradeMenu/Control")
	coins = SaveData.coins
	keys = Tuning.start_keys + carried_keys
	carried_keys = 0
	arrows = Tuning.start_arrows

func unregister(world: Overworld) -> void:
	if overworld == world:
		overworld = null
		player = null
		camera_rig = null
		camera = null
		upgrade_menu = null

func room_by_id(id: int) -> Room:
	return overworld.rooms_by_id.get(id)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

# The floor is done: the keys the end room took are spent, the rest wait for the next floor.
func finish_floor() -> void:
	carried_keys = maxi(keys - Tuning.keys_to_finish, 0)

func add_keys(amount: int) -> void:
	keys += amount
	keys_changed.emit(keys)

func add_arrows(amount: int) -> void:
	arrows = maxi(arrows + amount, 0)
	arrows_changed.emit(arrows)

# Moves the item bar's highlight by `step` boxes, wrapping round at either end.
func cycle_item(step: int) -> void:
	item_slot = posmod(item_slot + step, maxi(Tuning.item_slots, 1))
	item_selected.emit(item_slot)

# Items don't exist yet: for now using one only tells the HUD, which flashes the box.
func use_item() -> void:
	item_used.emit(item_slot)
