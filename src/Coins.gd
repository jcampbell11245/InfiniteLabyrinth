extends HBoxContainer

var coins = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$Counter/CoinText.set_text(str(coins))

func add_coins(add):
	coins += add
	$Counter/CoinText.set_text(str(coins))

func update_text():
	$Counter/CoinText.set_text(str(coins))
