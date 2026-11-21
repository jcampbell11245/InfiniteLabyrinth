extends Node

# Game-wide state and signals for the running floor, plus references to the long-lived
# nodes of the Overworld so other scripts don't have to walk the scene tree to find them.
# Overworld registers itself when it enters the tree.

signal room_entered(room_id: int) # The player walked into a room
signal coins_changed(coins: int)
signal keys_changed(keys: int)
signal arrows_changed(arrows: int)
signal arrows_empty # Tried to shoot with no arrows left
signal time_lost(seconds: float, fatal: bool) # Taken off the level timer by damage
signal fatal_countdown_finished # The timer has shown a killing hit draining it to 0:00
signal player_died
signal item_selected(slot: int) # The highlighted box on the item bar moved
signal item_used(slot: int, kind: Items.Kind) # The item in that box did its thing and is gone
signal item_refused(slot: int) # Use pressed on an empty box, or on an item that would do nothing
signal items_changed # What's in the item bar's boxes changed
signal room_marked(room_id: int) # A metal detector showed this key room on the minimap

enum Purchase { BOUGHT, TOO_POOR, BAR_FULL } # What came of trying to buy an item

var coins := 0 # Banked into SaveData when the floor ends
var keys := 0 # Held now; Tuning.keys_to_finish open the end room
# Spare keys from the floor just finished, added to the next floor's when it starts. Only
# set between finishing a floor and the next one starting, so a death or a new run gets none.
var carried_keys := 0
var arrows := 0 # Left to shoot; refilled to Tuning.start_arrows each floor
var item_slot := 0 # Highlighted box on the item bar, 0 to Tuning.item_slots - 1
var items: Array[Items.Kind] = [] # What's in each box of the item bar
# The items left when the floor just finished, handed to the next one like carried_keys:
# a death or a new run starts with an empty bar.
var carried_items: Array[Items.Kind] = []

# Keys given at the start of each floor and the floor a new run starts on are
# Tuning.start_keys and Tuning.start_floor (debug menu, F2).

var overworld: Overworld
var player: Player
var camera_rig: CharacterBody2D
var camera: ShakeCamera
var upgrade_menu: UpgradeMenu

func register(world: Overworld) -> void:
	overworld = world
	player = world.get_node("Player")
	camera_rig = world.get_node("CameraRig")
	camera = camera_rig.get_node("Camera2D")
	upgrade_menu = camera.get_node("UpgradeMenu/Control")
	coins = SaveData.coins
	keys = Tuning.start_keys + carried_keys
	carried_keys = 0
	arrows = Tuning.start_arrows
	items = carried_items.duplicate()
	carried_items = []
	items_changed.emit()

func unregister(world: Overworld) -> void:
	if overworld == world:
		overworld = null
		player = null
		camera_rig = null
		camera = null
		upgrade_menu = null

func _ready() -> void:
	player_died.connect(discard_items)

# Every unused item is lost when the player dies.
func discard_items() -> void:
	items.clear()
	items_changed.emit()

func room_by_id(id: int) -> Room:
	return overworld.rooms_by_id.get(id)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

# The floor is done: the keys the end room took are spent, the rest wait for the next floor.
func finish_floor() -> void:
	carried_keys = maxi(keys - Tuning.keys_to_finish, 0)
	carried_items = items.duplicate()

func add_keys(amount: int) -> void:
	keys += amount
	keys_changed.emit(keys)

func add_arrows(amount: int) -> void:
	arrows = maxi(arrows + amount, 0)
	arrows_changed.emit(arrows)

# Moves the item bar's highlight by `step` boxes, wrapping round at either end.
func cycle_item(step: int) -> void:
	item_slot = posmod(item_slot + step, maxi(Tuning.item_slots, 1))
	item_selected.emit(item_slot)

# The item in box `slot`, or NONE for an empty box (or one past the end of `items`).
func item_in(slot: int) -> Items.Kind:
	return items[slot] if slot >= 0 && slot < items.size() else Items.Kind.NONE

# The first empty box on the item bar, or -1 when every box is full.
func free_slot() -> int:
	for slot in maxi(Tuning.item_slots, 1):
		if item_in(slot) == Items.Kind.NONE:
			return slot
	return -1

# Buys `kind` for Items.price coins into the first empty box, if the player can pay and
# has room. The coins are banked with the rest when the floor ends (Overworld.reset_world).
func buy_item(kind: Items.Kind) -> Purchase:
	var cost := Items.price(kind)
	if coins < cost:
		return Purchase.TOO_POOR
	var slot := free_slot()
	if slot < 0:
		return Purchase.BAR_FULL
	if items.size() <= slot:
		items.resize(slot + 1) # New boxes are NONE, empty
	items[slot] = kind
	add_coins(-cost)
	items_changed.emit()
	return Purchase.BOUGHT

# Uses the highlighted item. It's only used up if it did something (see Items.use).
func use_item() -> void:
	var kind := item_in(item_slot)
	if kind == Items.Kind.NONE || !Items.use(kind):
		item_refused.emit(item_slot)
		return
	items[item_slot] = Items.Kind.NONE
	item_used.emit(item_slot, kind)
	items_changed.emit()
