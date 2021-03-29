extends HBoxContainer

var coins = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$Counter/CoinText.set_bbcode(String(coins))

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func add_coins(add):
	coins += add
	$Counter/CoinText.set_bbcode(String(coins))

func update_text():
	$Counter/CoinText.set_bbcode(String(coins))
