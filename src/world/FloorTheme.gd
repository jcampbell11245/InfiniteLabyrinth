class_name FloorTheme

# Swaps the room art to match the floor. Floor 1 uses the textures the rooms were made
# with. Later floors use the file with the same name under FLOOR2_DIR wherever one exists
# (tileset/stalagmites/stalagmites.png -> tileset/floor2/stalagmites/stalagmites.png), so
# new art takes over as soon as it is saved there, and anything without a floor-2 version
# keeps its floor-1 look. It covers TileMap tiles and the frames of sprites (the boss door).
#
# TileSets and SpriteFrames are shared by every instance of their scene, so a swap reaches
# every room using them. Each swapped texture remembers its floor-1 one, so going back to
# floor 1 restores it.

const TILESET_DIR := "res://assets/sprites/tileset/"
const FLOOR2_DIR := TILESET_DIR + "floor2/"
const BASE_TEXTURE_META := &"floor1_texture"
const BASE_FRAMES_META := &"floor1_frames" # On SpriteFrames: "animation/index" -> floor-1 texture

# The folder holding a floor's art, or "" for the textures the rooms were made with.
static func art_dir(floor_number: int) -> String:
	return "" if floor_number <= 1 else FLOOR2_DIR

static func uses_floor2_art(floor_number: int) -> bool:
	return art_dir(floor_number) != ""

# Points every TileMap and sprite under `root` (root included) at the floor's art.
static func apply(root: Node, floor_number: int) -> void:
	var dir := art_dir(floor_number)
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		if node is TileMap:
			_apply_to_tile_set((node as TileMap).tile_set, dir)
		elif node is TileMapLayer:
			_apply_to_tile_set((node as TileMapLayer).tile_set, dir)
		elif node is AnimatedSprite2D:
			_apply_to_sprite_frames((node as AnimatedSprite2D).sprite_frames, dir)
		elif node is Sprite2D:
			var sprite := node as Sprite2D
			sprite.texture = _swapped(sprite, sprite.texture, dir)

static func _apply_to_tile_set(tile_set: TileSet, dir: String) -> void:
	if tile_set == null:
		return
	for i in range(tile_set.get_source_count()):
		var source := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if source != null && source.texture != null:
			var wanted := _swapped(source, source.texture, dir)
			if source.texture != wanted:
				source.texture = wanted

# A frame cut from a sprite sheet (AtlasTexture) has its sheet swapped; a whole-image frame
# is replaced in the SpriteFrames.
static func _apply_to_sprite_frames(frames: SpriteFrames, dir: String) -> void:
	if frames == null:
		return
	var bases: Dictionary = frames.get_meta(BASE_FRAMES_META, {})
	for animation in frames.get_animation_names():
		for i in range(frames.get_frame_count(animation)):
			var texture := frames.get_frame_texture(animation, i)
			if texture is AtlasTexture:
				var atlas_texture := texture as AtlasTexture
				var wanted_atlas := _swapped(atlas_texture, atlas_texture.atlas, dir)
				if atlas_texture.atlas != wanted_atlas:
					atlas_texture.atlas = wanted_atlas
			elif texture != null:
				var key := "%s/%d" % [animation, i]
				if !bases.has(key):
					bases[key] = texture
				var wanted := _floor_texture(bases[key], dir)
				if texture != wanted:
					frames.set_frame(animation, i, wanted, frames.get_frame_duration(animation, i))
	frames.set_meta(BASE_FRAMES_META, bases)

# The texture `owner` should show on this floor. The first call stores `current` on the
# owner as its floor-1 texture.
static func _swapped(owner: Object, current: Texture2D, dir: String) -> Texture2D:
	if current == null:
		return null
	if !owner.has_meta(BASE_TEXTURE_META):
		owner.set_meta(BASE_TEXTURE_META, current)
	return _floor_texture(owner.get_meta(BASE_TEXTURE_META), dir)

# The floor-2 file of the same name if there is one and `dir` asks for it, else `base`.
static func _floor_texture(base: Texture2D, dir: String) -> Texture2D:
	if dir == "" || !base.resource_path.begins_with(TILESET_DIR):
		return base
	var path := dir + base.resource_path.trim_prefix(TILESET_DIR)
	# An animated .tres texture (uncovered_metal) can be replaced by a still .png.
	for candidate in [path, path.get_basename() + ".png"]:
		if ResourceLoader.exists(candidate):
			return load(candidate)
	return base
