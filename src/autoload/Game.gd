extends Node

# Game-wide state and signals for the running floor, plus references to the long-lived
# nodes of the Overworld so other scripts don't have to walk the scene tree to find them.
# Overworld registers itself when it enters the tree.

signal room_entered(room_id: int) # The player walked into a room
signal coins_changed(coins: int)
signal keys_changed(keys: int)
signal health_changed(health: float)
signal player_died

var coins := 0 # Banked into SaveData when the floor ends
var keys := 0 # Collected this floor; three open the end room

const DEBUG_START_KEYS := 0 # Keys given at the start of each floor. Raise it to test the end room quickly.
const START_FLOOR := 1 # Floor a new run starts on. Raise it to test a later floor's art.

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
	keys = DEBUG_START_KEYS

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

func add_keys(amount: int) -> void:
	keys += amount
	keys_changed.emit(keys)
