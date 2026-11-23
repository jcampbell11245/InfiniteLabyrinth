extends "res://tools/tests/test_case.gd"

# A knight's slash hitbox (MeleeEnemy.slash_boxes) sits inside its slash art on every
# facing, Tuning.slash_art_inset in from the art's far edge and sides, so a player standing
# just past the slash the player sees isn't hit, while one inside the hitbox still is.

const SWOOSH_ALPHA := 170.0 / 255.0 # The slash trail is drawn half see-through; the knight isn't
const ALPHA_TOLERANCE := 0.02
const FRAME_SIZE := Vector2(60, 60)
const OUTSIDE := 1.0 # Pixels past the art's far edge the player's hurtbox stands
const SETTLE_FRAMES := 3

func knight(kind := "knight") -> MeleeEnemy:
	var design := RoomDesign.new()
	design.set_object(Vector2i(6, 6), kind)
	Overworld.test_design = design
	await boot_floor()
	Overworld.test_design = null # So later tests get real floors
	var room: Room = autoload("Game").room_by_id(Overworld.TEST_ROOM_ID)
	for child in room.get_children():
		if child is MeleeEnemy:
			return child
	return null

# Freezes the knight mid-slash facing `dir`, blade live, with its AI stopped.
func freeze_slashing(k: MeleeEnemy, dir: String) -> void:
	k.set_process(false)
	k.set_physics_process(false)
	k.direction = dir
	k._point_pivots()
	k._play("slash")
	k.animator.frame = k.attack_frame # Turns the hitbox on (_on_animated_sprite_2d_frame_changed)
	k.animator.pause()

# Bounds of the slash trail over the swing from the strike on, in the slash's own axes:
# x forward from the knight's origin, y across (the hitbox's local axes, in pixels).
func art_bounds(k: MeleeEnemy, dir: String) -> Rect2:
	var frames := k.animator.sprite_frames
	var anim := "slash_" + dir
	var pivot: Node2D = k.get_node("HitboxPivot")
	var to_slash := Transform2D(pivot.global_rotation, Vector2.ZERO).affine_inverse() \
		* Transform2D(0.0, k.global_position).affine_inverse() * k.animator.global_transform
	var lo := Vector2(INF, INF)
	var hi := -lo
	for i in range(k.attack_frame, frames.get_frame_count(anim)):
		var image := frames.get_frame_texture(anim, i).get_image()
		for y in image.get_height():
			for x in image.get_width():
				if absf(image.get_pixel(x, y).a - SWOOSH_ALPHA) > ALPHA_TOLERANCE:
					continue
				for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y + 1)]:
					var p := to_slash * (corner - FRAME_SIZE / 2 + k.animator.offset)
					lo = lo.min(p)
					hi = hi.max(p)
	return Rect2(lo, hi - lo)

# The live hitbox in the same axes and units as art_bounds.
func hitbox_bounds(k: MeleeEnemy) -> Rect2:
	var rect := k.hitbox.shape as RectangleShape2D
	var s := absf(k.scale.x)
	return Rect2((k.hitbox.position - rect.size / 2) * s, rect.size * s)

# Puts the player so their hurtbox's near edge is `forward` pixels from the knight along
# `dir`, centred across on the knight's hitbox.
func place_player(k: MeleeEnemy, dir: String, forward: float) -> void:
	var player: Player = autoload("Game").player
	var fwd := Direction.to_vector(dir)
	var across := fwd.orthogonal() * -1.0 # The hitbox's local +y once its pivot turns
	var half: Vector2 = (player.hurtbox.shape as RectangleShape2D).size * player.global_scale.abs() / 2
	var half_along := absf(fwd.x) * half.x + absf(fwd.y) * half.y
	var centre := k.global_position + fwd * (forward + half_along) \
		+ across * hitbox_bounds(k).get_center().y
	player.global_position = centre - (player.hurtbox.global_position - player.global_position)

func player_was_hit() -> bool:
	return autoload("Game").player.invincibility_cooldown.time_left > 0

func settle() -> void:
	for i in SETTLE_FRAMES:
		await tree.physics_frame

func test_hitbox_sits_inside_the_slash_art() -> void:
	var k := await knight()
	var inset: float = autoload("Tuning").slash_art_inset
	for dir: String in [Direction.RIGHT, Direction.LEFT, Direction.UP, Direction.DOWN]:
		freeze_slashing(k, dir)
		var art := art_bounds(k, dir)
		var box := hitbox_bounds(k)
		expect(art.size.x > 0, "%s: the slash art has a trail to measure" % dir)
		expect_near(box.end.x, art.end.x - inset, 0.01, "%s: far edge %s px inside the art" % [dir, inset])
		expect_near(box.position.y, art.position.y + inset, 0.01, "%s: one side inside the art" % dir)
		expect_near(box.end.y, art.end.y - inset, 0.01, "%s: other side inside the art" % dir)

func test_player_just_past_the_slash_is_not_hit() -> void:
	for kind: String in ["knight", "dual_knight"]:
		var k := await knight(kind)
		var player: Player = autoload("Game").player
		# Held still, so a hit's knockback or turning (which shifts the hurtbox sideways)
		# can't move it between placing it and checking.
		player.set_process(false)
		player.set_physics_process(false)
		for dir: String in [Direction.RIGHT, Direction.LEFT, Direction.UP, Direction.DOWN]:
			freeze_slashing(k, dir)
			player.invincibility_cooldown.stop()
			place_player(k, dir, art_bounds(k, dir).end.x + OUTSIDE)
			await settle()
			expect(!player_was_hit(), "%s facing %s: player %s px past the slash isn't hit" % [kind, dir, OUTSIDE])
			# Step into the hitbox: the slash still lands.
			place_player(k, dir, hitbox_bounds(k).end.x - OUTSIDE)
			await settle()
			expect(player_was_hit(), "%s facing %s: player inside the hitbox is hit" % [kind, dir])
			player.invincibility_cooldown.stop()
			place_player(k, dir, art_bounds(k, dir).end.x + 20.0) # Clear, before the next facing
			await settle()
