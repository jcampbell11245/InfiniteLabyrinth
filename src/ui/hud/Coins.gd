extends HBoxContainer

# Shows Game.coins.

func _ready():
	Game.coins_changed.connect(_show)
	_show(Game.coins)

func _show(coins):
	$Counter/CoinText.set_text(str(coins))
