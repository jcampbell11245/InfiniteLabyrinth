class_name Troll
extends MeleeEnemy

# A goblin that goes for the player's purse. Its slash does half a goblin's damage, but
# every hit that lands takes Tuning.troll_steal coins (per floor number) from the player:
# the "bad" coin sound plays and the coins fly out of the HUD's coin icon into the troll.
# It keeps what it steals and drops it back, on top of its own reward, when it dies, all
# but a few coins (Tuning.troll_coin_loss_chance each) that are lost for good.

const StolenCoin := preload("res://src/effects/StolenCoin.gd")
const MAX_FLYING_COINS := 4 # Coins drawn flying per theft, however many are taken
const COIN_STAGGER := 0.06 # Seconds between each flying coin setting off

var stolen := 0 # Coins taken so far, given back when it dies

# The player called this: one of this troll's slashes just took health off them.
func landed_hit() -> void:
	super()
	var amount := mini(roundi(Tuning.troll_steal * Game.overworld.floor_number), Game.coins)
	if amount <= 0:
		return
	stolen += amount
	Game.add_coins(-amount)
	Juice.coin_stolen_sound()
	var from := _hud_coin_position()
	@warning_ignore("integer_division")
	var count := clampi(amount / 5, 1, MAX_FLYING_COINS)
	for i in count:
		var coin: Sprite2D = StolenCoin.new()
		coin.target = self
		coin.delay = i * COIN_STAGGER
		room.add_child(coin)
		coin.global_position = from

# The HUD coin icon's spot in the world, where stolen coins set off from. Falls back to the
# player if the HUD can't be found (the room creator's play-test has one, but be safe).
func _hud_coin_position() -> Vector2:
	var icon: CanvasItem = null
	if Game.camera != null:
		icon = Game.camera.get_node_or_null("HudLayer/Hud/Coins/Coin")
	if icon == null:
		return player.global_position
	var on_screen := icon.get_global_transform_with_canvas().origin
	return get_viewport().get_canvas_transform().affine_inverse() * on_screen

# Each stolen coin has Tuning.troll_coin_loss_chance of being gone for good.
func die() -> void:
	var recovered := 0
	for i in stolen:
		if randf() >= Tuning.troll_coin_loss_chance:
			recovered += 1
	Juice.drop_coins(room, global_position, recovered)
	stolen = 0
	super()
