extends Node

# References to the long-lived nodes of the running Overworld, so other scripts don't
# have to walk the scene tree to find them. Set by Overworld when it enters the tree.

var overworld
var player
var camera_rig
var camera
var coins
var keys
var hearts
var timer_text
var game_over
var upgrade_menu

func register(world):
	overworld = world
	player = world.get_node("Player")
	camera_rig = world.get_node("CameraRig")
	camera = camera_rig.get_node("Camera2D")
	var hud = camera.get_node("HudLayer/Hud")
	coins = hud.get_node("Coins")
	keys = hud.get_node("Keys")
	hearts = hud.get_node("Hearts")
	timer_text = hud.get_node("Timer/TimerText")
	game_over = camera.get_node("GameOver")
	upgrade_menu = camera.get_node("UpgradeMenu/Control")

func unregister(world):
	if overworld == world:
		overworld = null
		player = null
		camera_rig = null
		camera = null
		coins = null
		keys = null
		hearts = null
		timer_text = null
		game_over = null
		upgrade_menu = null
