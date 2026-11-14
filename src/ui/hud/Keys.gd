extends HBoxContainer

# Shows Game.keys.

func _ready() -> void:
	Game.keys_changed.connect(_show)
	_show(Game.keys)

func _show(keys: int) -> void:
	$Counter/KeyText.set_text(str(keys))
