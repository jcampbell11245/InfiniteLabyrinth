extends HBoxContainer

# Shows Game.arrows, popping the icon and number whenever it changes. Trying to shoot
# with none left flashes the counter red and shakes it.

const POP := 1.4
const POP_TIME := 0.2
const EMPTY_COLOR := Color(1, 0.25, 0.25)
const SHAKE_DISTANCE := 1.5 # Hud pixels
const SHAKE_TIME := 0.25

var _icon_scale := Vector2.ONE
var _counter_scale := Vector2.ONE
var _counter_position := Vector2.ZERO
var _shown := -1

func _ready() -> void:
	_icon_scale = $Icon.scale
	_counter_scale = $Counter.scale
	_counter_position = $Counter.position
	Game.arrows_changed.connect(_show)
	Game.arrows_empty.connect(_flash_empty)
	_show(Game.arrows)

func _show(arrows: int) -> void:
	$Counter/ArrowText.set_text(str(arrows))
	if _shown != -1 && arrows > _shown:
		_pop($Icon, _icon_scale)
		_pop($Counter, _counter_scale)
	_shown = arrows

func _pop(node: Node2D, base: Vector2) -> void:
	node.scale = base * POP
	node.create_tween().tween_property(node, "scale", base, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _flash_empty() -> void:
	var counter: Node2D = $Counter
	counter.modulate = EMPTY_COLOR
	var tween := counter.create_tween()
	for i in 4:
		var dx := SHAKE_DISTANCE if i % 2 == 0 else -SHAKE_DISTANCE
		tween.tween_property(counter, "position", _counter_position + Vector2(dx, 0), SHAKE_TIME / 5)
	tween.tween_property(counter, "position", _counter_position, SHAKE_TIME / 5)
	tween.parallel().tween_property(counter, "modulate", Color.WHITE, SHAKE_TIME)
