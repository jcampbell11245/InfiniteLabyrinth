extends HBoxContainer

# Shows Game.coins.

func _ready() -> void:
	Game.coins_changed.connect(_show)
	_show(Game.coins)

func _show(coins: int) -> void:
	$Counter/CoinText.set_text(str(coins))
