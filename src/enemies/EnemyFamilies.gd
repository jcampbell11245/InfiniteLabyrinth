class_name EnemyFamilies
extends RefCounted

# Enemy families: alternate versions of a base enemy that share its sprites and AI with
# different stats or a twist. For now only the goblin's:
#   Troll  gold-tinted goblin; half the damage, but each hit steals coins (see Troll.gd)
#   Orc    goblin at twice the size; hits twice as hard, twice the health, walks slower
#
# Rooms are built by hand with goblins in them. As a floor is laid out, each goblin rolls
# Tuning.troll_chance / Tuning.orc_chance to be swapped for one of its family instead.
# The room creator can also place trolls and orcs directly; those are left alone.

const GOBLIN := "res://src/enemies/Goblin.tscn"
const TROLL := preload("res://src/enemies/Troll.tscn")
const ORC := preload("res://src/enemies/Orc.tscn")

# What a room sets on the enemies it places, carried over to the replacement.
const KEPT_PROPERTIES: Array[String] = [
	"position", "starting_direction", "detection_radius", "roam_mode", "roam_path", "roam_area",
]

# Swaps some of `room`'s goblins for trolls and orcs. Call before the room enters the tree,
# so nothing has run on the goblins yet.
static func roll_variants(room: Node) -> void:
	for child in room.get_children():
		if child.scene_file_path != GOBLIN:
			continue
		var roll := randf()
		var variant: PackedScene = null
		if roll < Tuning.troll_chance:
			variant = TROLL
		elif roll < Tuning.troll_chance + Tuning.orc_chance:
			variant = ORC
		if variant != null:
			_replace(child, variant.instantiate())

static func _replace(old: Node, new: Node) -> void:
	for property in KEPT_PROPERTIES:
		new.set(property, old.get(property))
	var parent := old.get_parent()
	var index := old.get_index()
	var old_name := old.name
	parent.remove_child(old)
	old.free()
	new.name = old_name
	parent.add_child(new, true)
	parent.move_child(new, index)
