extends HBoxContainer

# Shows Game.keys.

func _ready():
	Game.keys_changed.connect(_show)
	_show(Game.keys)

func _show(keys):
	$Counter/KeyText.set_text(str(keys))
