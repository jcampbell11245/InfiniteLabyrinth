class_name Merchant
extends StaticBody2D

# The merchant standing at the top of the start room, who sells consumable items. When the
# player walks up close (within Tuning.merchant_reach of his feet) a button prompt floats
# over his head; pressing interact has him offer his wares in a dialogue box (DialogueBox),
# and moving that on opens his shop (ShopMenu). Both pause the game, but not the music.
# He's solid, like a wall, so the player walks up to him rather than through him.
# In the tutorial he gives Tutorial.WELCOME instead and has no shop to open; `talked` tells
# the tutorial he's done (Tutorial).
#
# The node's origin is at his feet; the sprite (32x32, drawn at 1x like the rest of the
# pixel art) stands on it, its bottom row on the origin.

const PROMPT_HEIGHT := 39.0 # World pixels above his feet where the prompt floats (his hat is 31 tall)
const SHOP_LAYER := 50 # Over the HUD
const NAME := "Shopkeeper"
const GREETING: Array[String] = ["Care to browse my wares?"]

signal talked # The player moved his last line on, in the tutorial

var _shop: ShopMenu
var _dialogue: DialogueBox
@onready var prompt: ButtonPrompt = $Prompt

func _ready() -> void:
	prompt.position = Vector2(0, -PROMPT_HEIGHT)
	prompt.visible = false
	var layer := CanvasLayer.new()
	layer.layer = SHOP_LAYER
	add_child(layer)
	_shop = ShopMenu.new()
	layer.add_child(_shop)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	_shop.closed.connect(Music.play_through_pause.bind(false))

# The prompts follow the device the player last touched.
func _input(event: InputEvent) -> void:
	InputGlyphs.note(event)

func _physics_process(_delta: float) -> void:
	var near := in_reach()
	prompt.visible = near
	if near && Input.is_action_just_pressed("interact"):
		prompt.visible = false
		talk()

# Greets the player; the shop opens once they move the greeting on.
func talk() -> void:
	Music.play_through_pause(true)
	_dialogue.say(NAME, Tutorial.WELCOME if Overworld.tutorial else GREETING)

func _on_dialogue_finished() -> void:
	if !Overworld.tutorial:
		_shop.open()
		return
	Music.play_through_pause(false)
	talked.emit()

# True while the player is close enough to talk to him and free to do so.
func in_reach() -> bool:
	var player := Game.player
	var room := get_parent() as Room
	if player == null || _shop.visible || _dialogue.visible || (room != null && player.current_room != room.room_id):
		return false
	if !player.can_act():
		return false
	return (player.global_position + Player.FEET).distance_to(global_position) <= Tuning.merchant_reach
