class_name Items
extends RefCounted

# The consumable items that go in the item bar's boxes (ItemBar) and what using each one
# does. Game keeps which item is in each box; Game.use_item calls use() on the highlighted
# one and only takes it away when use() says it did something, so an item that would be
# wasted (a skeleton key with no locked door to open) stays in its box.
#
# Items can't be found yet: for now every floor starts with STARTING in the first boxes.

enum Kind { NONE, SKELETON_KEY, METAL_DETECTOR }

const STARTING: Array[Kind] = [Kind.SKELETON_KEY, Kind.METAL_DETECTOR]

# Placeholders, listed in PENDING_ASSETS.md.
const ICONS := {
	Kind.SKELETON_KEY: preload("res://assets/sprites/hud/item_skeleton_key.png"),
	Kind.METAL_DETECTOR: preload("res://assets/sprites/hud/item_metal_detector.png"),
}

# Does what `kind` does, if it can do anything right now. True when it did, and so is used up.
static func use(kind: Kind) -> bool:
	match kind:
		Kind.SKELETON_KEY: return _use_skeleton_key()
		Kind.METAL_DETECTOR: return _use_metal_detector()
	return false

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
