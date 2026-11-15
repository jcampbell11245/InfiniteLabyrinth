extends HBoxContainer

# Shows Game.keys, popping the icon and number whenever it changes.

const POP := 1.4
const POP_TIME := 0.2

var _icon_scale := Vector2.ONE
var _counter_scale := Vector2.ONE
var _shown := -1

func _ready() -> void:
	_icon_scale = $Key.scale
	_counter_scale = $Counter.scale
	Game.keys_changed.connect(_show)
	_show(Game.keys)

func _show(keys: int) -> void:
	$Counter/KeyText.set_text(str(keys))
	if _shown != -1 && keys != _shown:
		_pop($Key, _icon_scale)
		_pop($Counter, _counter_scale)
	_shown = keys

func _pop(node: Node2D, base: Vector2) -> void:
	node.scale = base * POP
	node.create_tween().tween_property(node, "scale", base, POP_TIME) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
