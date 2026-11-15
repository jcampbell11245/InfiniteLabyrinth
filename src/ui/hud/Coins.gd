extends HBoxContainer

# Shows Game.coins, popping the icon and number whenever it changes.

const POP := 1.4
const POP_TIME := 0.2

var _icon_scale := Vector2.ONE
var _counter_scale := Vector2.ONE
var _shown := -1

func _ready() -> void:
	_icon_scale = $Coin.scale
	_counter_scale = $Counter.scale
	Game.coins_changed.connect(_show)
	_show(Game.coins)

func _show(coins: int) -> void:
	$Counter/CoinText.set_text(str(coins))
	if _shown != -1 && coins != _shown:
		_pop($Coin, _icon_scale)
		_pop($Counter, _counter_scale)
	_shown = coins

func _pop(node: Node2D, base: Vector2) -> void:
	node.scale = base * POP
	node.create_tween().tween_property(node, "scale", base, POP_TIME) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
