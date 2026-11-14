class_name UpgradeMenu
extends Control

# Between floors (and after dying) the player spends coins on four upgrades, each with
# MAX_LEVEL levels, then continues to a new floor. Rows are picked with up/down or the
# mouse; the row after the upgrades is Continue.

const MAX_LEVEL := 9
const COSTS := [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, "MAX"] # By current level

# One row per upgrade: its SaveData field and the nodes that show it.
const UPGRADES := [
	{level = "health_level", meter = "Meter1", cost = "Coins", option = "Plus1Control", plus = "Plus1Control/Plus1", button = "Plus1Control/Button"},
	{level = "damage_level", meter = "Meter2", cost = "Coins2", option = "Plus2Control", plus = "Plus2Control/Plus2", button = "Plus2Control/Button2"},
	{level = "time_level", meter = "Meter3", cost = "Coins3", option = "Plus3Control", plus = "Plus3Control/Plus3", button = "Plus3Control/Button3"},
	{level = "looting_level", meter = "Meter4", cost = "Coins4", option = "Plus4Control", plus = "Plus4Control/Plus4", button = "Plus4Control/Button4"},
]
const CONTINUE := 4 # Row index of the Continue button

var selected := 0

func _ready() -> void:
	for i in range(UPGRADES.size()):
		var upgrade: Dictionary = UPGRADES[i]
		get_node(upgrade.option).mouse_entered.connect(_select.bind(i))
		get_node(upgrade.button).pressed.connect(buy.bind(i))
		get_node(upgrade.meter).animation = str(_level(i) + 1)
	$Continue.mouse_entered.connect(_select.bind(CONTINUE))
	$Continue.pressed.connect(continue_to_next_floor)
	_select(0)

func _process(_delta: float) -> void:
	if !visible:
		return
	if Input.is_action_just_released("up") && selected != 0:
		_select(selected - 1)
	if Input.is_action_just_released("down") && selected != CONTINUE:
		_select(selected + 1)
	if Input.is_action_just_released("select"):
		if selected == CONTINUE:
			continue_to_next_floor()
		else:
			buy(selected)

# Toggles the menu along with the pause state.
func show_menu() -> void:
	var new_pause_state := !get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state
	for i in range(UPGRADES.size()):
		get_node(UPGRADES[i].cost).text = str(COSTS[_level(i)])
	_select(0)

func buy(index: int) -> void:
	var level := _level(index)
	if level == MAX_LEVEL || Game.coins < COSTS[level]:
		return
	Game.add_coins(-COSTS[level])
	SaveData.set(UPGRADES[index].level, level + 1)
	get_node(UPGRADES[index].meter).animation = str(level + 2)
	get_node(UPGRADES[index].cost).text = str(COSTS[level + 1])
	SaveData.save()

func continue_to_next_floor() -> void:
	show_menu()
	SaveData.save()
	Game.overworld.reset_world()

func _level(index: int) -> int:
	return SaveData.get(UPGRADES[index].level)

func _select(index: int) -> void:
	selected = index
	for i in range(UPGRADES.size()):
		var plus: AnimatedSprite2D = get_node(UPGRADES[i].plus)
		plus.animation = "selected" if i == selected else "default"
	$ContinueOutline.visible = selected == CONTINUE
