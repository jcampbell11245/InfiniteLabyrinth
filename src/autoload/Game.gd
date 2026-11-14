extends Node

# Game-wide state and signals for the running floor, plus references to the long-lived
# nodes of the Overworld so other scripts don't have to walk the scene tree to find them.
# Overworld registers itself when it enters the tree.

signal room_entered(room_id) # The player walked into a room
signal coins_changed(coins)
signal keys_changed(keys)
signal health_changed(health)
signal player_died

var coins = 0 # Banked into SaveData when the floor ends
var keys = 0 # Collected this floor; three open the end room

var overworld
var player
var camera_rig
var camera
var upgrade_menu

func register(world):
	overworld = world
	player = world.get_node("Player")
	camera_rig = world.get_node("CameraRig")
	camera = camera_rig.get_node("Camera2D")
	upgrade_menu = camera.get_node("UpgradeMenu/Control")
	coins = SaveData.coins
	keys = 0

func unregister(world):
	if overworld == world:
		overworld = null
		player = null
		camera_rig = null
		camera = null
		upgrade_menu = null

func room_by_id(id):
	return overworld.rooms_by_id.get(id)

func add_coins(amount):
	coins += amount
	coins_changed.emit(coins)

func add_keys(amount):
	keys += amount
	keys_changed.emit(keys)
