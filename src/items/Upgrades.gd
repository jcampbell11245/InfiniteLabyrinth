class_name Upgrades
extends RefCounted

# The lasting upgrades the merchant sells on his shop's Upgrades tab (ShopMenu). Each has
# MAX_LEVEL levels, kept in SaveData so they last from run to run, and gets dearer with
# every level. Time adds Tuning.time_per_level seconds to the floor's clock; Looting adds
# a tenth of a coin per kill per level (Enemy's coin drop).

enum Kind { TIME, LOOTING }

const MAX_LEVEL := 9
# Price of the next level, by the current level: cheap early levels, about 150 * 1.55^level
# rounded to 50. Scaled by Tuning.upgrade_cost_multiplier.
const COSTS: Array[int] = [150, 250, 350, 550, 850, 1350, 2100, 3200, 5000]

const FIELDS := {Kind.TIME: "time_level", Kind.LOOTING: "looting_level"} # In SaveData
const NAMES := {Kind.TIME: "Time", Kind.LOOTING: "Looting"}
# Placeholders, listed in PENDING_ASSETS.md.
const ICONS := {
	Kind.TIME: preload("res://assets/sprites/hud/upgrade_time.png"),
	Kind.LOOTING: preload("res://assets/sprites/hud/upgrade_looting.png"),
}

# The shop's line for `kind`. The HUD font has capitals only and no apostrophes.
static func description(kind: Kind) -> String:
	match kind:
		Kind.TIME: return "%d more seconds on the clock every floor" % roundi(Tuning.time_per_level)
		Kind.LOOTING: return "More coins from every enemy you kill"
	return ""

static func level(kind: Kind) -> int:
	return SaveData.get(FIELDS[kind])

# Coins for the next level of `kind`, or -1 when it's at MAX_LEVEL.
static func price(kind: Kind) -> int:
	var current := level(kind)
	if current >= MAX_LEVEL:
		return -1
	return roundi(COSTS[current] * Tuning.upgrade_cost_multiplier)

# Buys the next level of `kind` if the player can pay. It's saved at once, coins and all, so
# leaving the run straight after can't get the coins back. A Time level also goes on the
# clock that's running now.
static func buy(kind: Kind) -> Game.Purchase:
	var cost := price(kind)
	if cost < 0:
		return Game.Purchase.MAXED
	if Game.coins < cost:
		return Game.Purchase.TOO_POOR
	Game.add_coins(-cost)
	SaveData.coins = maxi(SaveData.coins - cost, 0) # Banked coins; the rest are banked later
	SaveData.set(FIELDS[kind], level(kind) + 1)
	SaveData.save()
	if kind == Kind.TIME && Game.player != null && !Game.player.level_countdown.is_stopped():
		var countdown: Timer = Game.player.level_countdown
		countdown.start(countdown.time_left + Tuning.time_per_level)
	return Game.Purchase.BOUGHT
