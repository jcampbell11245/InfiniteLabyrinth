class_name Merchant
extends StaticBody2D

# The merchant standing at the top of the start room, who sells consumable items. When the
# player walks up close (within Tuning.merchant_reach of his feet) a button prompt floats
# over his head; pressing interact then opens his shop (ShopMenu), which pauses the game.
# He's solid, like a wall, so the player walks up to him rather than through him.
#
# The node's origin is at his feet; the sprite stands on it.

const PROMPT_HEIGHT := 46.0 # World pixels above his feet where the prompt floats
const SHOP_LAYER := 50 # Over the HUD

var _shop: ShopMenu
@onready var prompt: ButtonPrompt = $Prompt

func _ready() -> void:
	prompt.position = Vector2(0, -PROMPT_HEIGHT)
	prompt.visible = false
	var layer := CanvasLayer.new()
	layer.layer = SHOP_LAYER
	add_child(layer)
	_shop = ShopMenu.new()
	layer.add_child(_shop)

# The prompts follow the device the player last touched.
func _input(event: InputEvent) -> void:
	InputGlyphs.note(event)

func _physics_process(_delta: float) -> void:
	var near := in_reach()
	prompt.visible = near
	if near && Input.is_action_just_pressed("interact"):
		prompt.visible = false
		_shop.open()

# True while the player is close enough to talk to him and free to do so.
func in_reach() -> bool:
	var player := Game.player
	var room := get_parent() as Room
	if player == null || _shop.visible || (room != null && player.current_room != room.room_id):
		return false
	if !player.can_act():
		return false
	return (player.global_position + Player.FEET).distance_to(global_position) <= Tuning.merchant_reach
