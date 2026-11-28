class_name Items
extends RefCounted

# The consumable items that go in the item bar's boxes (ItemBar) and what using each one
# does. Game keeps which item is in each box; Game.use_item calls use() on the highlighted
# one and only takes it away when use() says it did something, so an item that would be
# wasted (a skeleton key with no locked door to open) stays in its box.
#
# Items are bought from the merchant in the start room (Merchant, ShopMenu), carried from
# floor to floor, and lost on death.
#
# The lucky cat, ram stick and broken watch are boosts that last a few seconds, and the
# preowned mace charges the next swing; ItemEffects keeps track of those once used.

enum Kind { NONE, SKELETON_KEY, METAL_DETECTOR, LUCKY_CAT, RAM_STICK, PREOWNED_MACE, BROKEN_WATCH }

# What the shop shows for each item. The HUD font has capitals only and no apostrophes. A
# %d in the text is the seconds the item lasts (duration).
const INFO := {
	Kind.SKELETON_KEY: {name = "Skeleton key", text = "Opens the locked doors of the room you are in"},
	Kind.METAL_DETECTOR: {name = "Metal detector", text = "Reveals a key room you have not found on the minimap"},
	Kind.LUCKY_CAT: {name = "Lucky cat", text = "Enemies drop far more coins and arrows for %d s"},
	Kind.RAM_STICK: {name = "Ram stick", text = "A longer window to parry in for %d s"},
	Kind.PREOWNED_MACE: {name = "Preowned mace", text = "Your next swing dazes every enemy it hits"},
	Kind.BROKEN_WATCH: {name = "Broken watch", text = "Stops the clock for %d s, even when you are hit"},
}

# Placeholders, listed in PENDING_ASSETS.md.
const ICONS := {
	Kind.SKELETON_KEY: preload("res://assets/sprites/hud/item_skeleton_key.png"),
	Kind.METAL_DETECTOR: preload("res://assets/sprites/hud/item_metal_detector.png"),
	Kind.LUCKY_CAT: preload("res://assets/sprites/hud/item_lucky_cat.png"),
	Kind.RAM_STICK: preload("res://assets/sprites/hud/item_ram_stick.png"),
	Kind.PREOWNED_MACE: preload("res://assets/sprites/hud/item_preowned_mace.png"),
	Kind.BROKEN_WATCH: preload("res://assets/sprites/hud/item_broken_watch.png"),
}

# The shop's line for `kind`, with its duration filled in.
static func description(kind: Kind) -> String:
	var text: String = INFO[kind].text
	return text % roundi(duration(kind)) if text.contains("%d") else text

# Coins the merchant asks for `kind` (Tuning, so the debug menu can change it).
static func price(kind: Kind) -> int:
	match kind:
		Kind.SKELETON_KEY: return Tuning.skeleton_key_price
		Kind.METAL_DETECTOR: return Tuning.metal_detector_price
		Kind.LUCKY_CAT: return Tuning.lucky_cat_price
		Kind.RAM_STICK: return Tuning.ram_stick_price
		Kind.PREOWNED_MACE: return Tuning.preowned_mace_price
		Kind.BROKEN_WATCH: return Tuning.broken_watch_price
	return 0

# Seconds a timed item lasts once used, 0 for the rest.
static func duration(kind: Kind) -> float:
	match kind:
		Kind.LUCKY_CAT: return Tuning.lucky_cat_time
		Kind.RAM_STICK: return Tuning.ram_stick_time
		Kind.BROKEN_WATCH: return Tuning.broken_watch_time
	return 0.0

# Does what `kind` does, if it can do anything right now. True when it did, and so is used up.
static func use(kind: Kind) -> bool:
	match kind:
		Kind.SKELETON_KEY: return _use_skeleton_key()
		Kind.METAL_DETECTOR: return _use_metal_detector()
		Kind.LUCKY_CAT, Kind.RAM_STICK: return _start_effect(kind)
		Kind.PREOWNED_MACE: return _use_preowned_mace()
		Kind.BROKEN_WATCH: return _use_broken_watch()
	return false

# A timed boost goes on (or gets longer, if it's on already).
static func _start_effect(kind: Kind) -> bool:
	var effects := ItemEffects.current()
	if effects == null:
		return false
	effects.start(kind, duration(kind))
	return true

# Charges the next swing. A second mace while one is charged would be wasted.
static func _use_preowned_mace() -> bool:
	var effects := ItemEffects.current()
	if effects == null || effects.mace_charged:
		return false
	effects.mace_charged = true
	effects.changed.emit()
	return true

# Only where the clock runs: in the start and end rooms it already stands still
# (LevelCountdown), so the watch would be wasted there.
static func _use_broken_watch() -> bool:
	var player := Game.player
	if player == null || player.level_countdown.is_stopped() 			|| player.current_room in [Constants.START_ROOM, Constants.END_ROOM]:
		return false
	return _start_effect(Kind.BROKEN_WATCH)

# Opens the locked doors of the player's room, as if they'd cleared it. The end room's key
# gate isn't a locked door in this sense: it still needs the floor's keys.
static func _use_skeleton_key() -> bool:
	var room := Game.room_by_id(Game.player.current_room)
	if room == null || !room.has_locked_doors():
		return false
	room.force_unlock()
	return true

# Shows one key room the player hasn't found yet on the minimap.
static func _use_metal_detector() -> bool:
	var hidden := unmarked_key_rooms()
	if hidden.is_empty():
		return false
	var room: Room = hidden.pick_random()
	room.marked = true
	Game.room_marked.emit(room.room_id)
	return true

# Key rooms the minimap doesn't show yet: not visited (which shows them) and not marked by
# a metal detector.
static func unmarked_key_rooms() -> Array[Room]:
	var found: Array[Room] = []
	if Game.overworld == null:
		return found
	for room: Room in Game.overworld.rooms_by_id.values():
		if room.is_key_room() && !room.visited && !room.marked:
			found.append(room)
	return found
