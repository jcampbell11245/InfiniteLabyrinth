extends HBoxContainer

var keys = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$Counter/KeyText.set_text(str(keys))

func add_keys(add):
	keys += add
	$Counter/KeyText.set_text(str(keys))

func get_keys():
	return keys
