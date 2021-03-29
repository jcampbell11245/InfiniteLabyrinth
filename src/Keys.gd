extends Node2D

var keys = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$Counter/KeyText.set_bbcode(String(keys))

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func add_keys(add):
	keys += add
	$Counter/KeyText.set_bbcode(String(keys))

func get_coins():
	return keys
