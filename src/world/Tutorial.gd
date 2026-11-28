class_name Tutorial
extends Node

# Runs the tutorial's script: what the merchant says and what it unlocks. Overworld adds one
# when it builds the tutorial (F3 on the title screen).
#
# Talking to the merchant in the start room gets WELCOME (Merchant says it); once it's moved
# on, the start room's lever-locked door opens. Walking into the first room has him speak up
# about the minimap, though he isn't there, and opening that room's chest has him explain
# the key. His remote lines wait for the player to finish walking through a doorway, so the
# box doesn't freeze them mid-step.

const WELCOME: Array[String] = [
	"Welcome to Infinite Labyrinth. [insert story]",
	"I will guide you through some of the basics.",
]
const MINIMAP: Array[String] = [
	"Take a look at your minimap.",
	"You can see the starting and ending rooms in green. Chest rooms are highlighted in yellow.",
]
const KEY: Array[String] = [
	"Oh good, a key!",
	"Normally you'll need two of these to unlock the end door, but for now one will do.",
]
const MINIMAP_ROOM := 0 # Room id of the first tutorial room, which holds the chest
const KEY_LINE_DELAY := 0.6 # Seconds after the chest opens, so the key is seen popping out

var _dialogue: DialogueBox
var _minimap_said := false
var _waiting: Array[String] = [] # Lines to say once the player is free to hear them
var _wait_left := 0.0 # Game seconds before they may start

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = Merchant.SHOP_LAYER
	add_child(layer)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_dialogue.finished.connect(Music.play_through_pause.bind(false))
	Game.room_entered.connect(_on_room_entered)

	var start := Game.room_by_id(Constants.START_ROOM)
	(start.get_node("Merchant") as Merchant).talked.connect(start.release_doors)
	var chest := Game.room_by_id(MINIMAP_ROOM).get_node_or_null("Chest")
	if chest != null:
		chest.opened.connect(_say_later.bind(KEY, KEY_LINE_DELAY))

func _process(delta: float) -> void:
	if _waiting.is_empty():
		return
	_wait_left -= delta
	var player := Game.player
	if _wait_left > 0.0 || _dialogue.visible || player == null || player.in_transition:
		return
	Music.play_through_pause(true)
	_dialogue.say(Merchant.NAME, _waiting)
	_waiting = []

# True while the merchant has something to say or is saying it.
func is_speaking() -> bool:
	return _dialogue.visible || !_waiting.is_empty()

func _say_later(lines: Array[String], delay := 0.0) -> void:
	_waiting = lines
	_wait_left = delay

func _on_room_entered(id: int) -> void:
	if id == MINIMAP_ROOM && !_minimap_said:
		_minimap_said = true
		_say_later(MINIMAP)
