# Known bugs

Bugs found during the Godot 4 refactor. The refactor keeps current behaviour on purpose,
so these are left as-is and fixed in a separate bugfix pass afterwards.

## Gameplay

- **Pitfalls deactivate the wrong room.** `Player._on_feet_box_body_entered` and
  `_on_respawn_cooldown_timeout` toggle `player_active` on `get_parent().get_child(current_room + 3)`,
  but generated rooms start at child index 6 (`set_last_tile` uses `+ 6`). Enemies in the room
  you fell in keep attacking while you're invisible; an unrelated room gets paused instead.
- **Upgrades never persist between launches.** `Boot.gd` calls `SaveData.reset()` every time
  the game starts, wiping floor, coins and all four upgrades.
- **The floor number never goes up.** Nothing increments `SaveData.floor_number`, so every
  floor is floor 1 and the coin multiplier never grows. Dying sets it to 1, then the upgrade
  menu's Continue writes the Overworld's old `floor_number` back over it.
- **Time and Looting upgrades save even when the purchase fails.** In `UpgradeMenu.gd`,
  `buy_time()` / `buy_looting()` call `SaveData.save()` outside the `if` that checks coins
  (`buy_health` / `buy_damage` don't). Harmless since nothing changed, but inconsistent.
- **Respawning plays a missing animation.** After a pitfall, `Player._on_respawn_cooldown_timeout`
  calls `take_damage(0.5, "none", true)`, which plays `damage_none`. That animation doesn't
  exist, so Godot logs an error and the sprite keeps its previous animation.
- **Coin drop formula has precedence bugs.** `MeleeEnemy.die()` uses
  `10 * floor * 1+((looting + 1 /10))`, which is `10 * floor + looting` (and `1 / 10` is 0).
  `ProjectileEnemy.die()` uses `1+((looting + 1)/10)` instead, so the two enemy types scale differently.
- **Wizard crits are not random per run.** `ProjectileEnemy.take_damage` creates a
  `RandomNumberGenerator` without calling `randomize()`, so it always rolls the same first number.
- **Boss uses a hard-coded room id.** `Boss.gd` checks `player.current_room == Constants.BOSS_ROOM`
  everywhere instead of its parent's `room_id`.
- **Camera and respawn drift 3px per column.** Rooms are placed 264px apart
  (`Constants.ROOM_SIZE.x`), but `CameraRig`, `Player.set_last_tile` and `Player.transition`
  step 261px (`Constants.LEGACY_ROOM_WIDTH`). By the last column the camera is 15px off-centre
  and respawn points are 15px off their tiles.

## Level generation (`Level.gd`)

- **Transition detectors are always placed.** Conditions like
  `get_cell_source_id(...) == 1 || 20 || 21` and `... == 2 || 3` are always true because the
  bare numbers are truthy, so detectors are added on the top and left walls of every room
  regardless of tiles.
- **The left-door detector checks the right-door lock cell.** The `(8, 13)` detector condition
  reads `$Locks.get_cell_source_id(0, Vector2i(18, 13))`.
- **Decoration variants overwrite each other.** In `_ready`, the `if variant < 60 / < 64 / < 66`
  chain isn't `elif`, so a roll of 59 sets three different decorations in a row (the last one wins)
  and decoration 0 effectively never appears.
- **Skipped tiles from the Godot 4 conversion.** 318 cells whose tile ids no longer existed in
  their Godot 3 tilesets were dropped during the tile-data restore (mostly `Top` id 5,
  `Pitfalls` ids 1–2, `Tiles` ids 41–43). Godot 3 drew nothing for these either, but it's worth
  checking that no room relied on them for collision.
- **Per-room collision overrides were lost.** In Godot 3, BossRoom's (formerly B1) `TopWalls` used collision layer 257
  and R1/R32 changed `Top`'s mask on the node. Godot 4 keeps collision on the shared TileSet, so
  those rooms now use the default tileset layers.

## Engine / cleanup

- **Dead enemies are never freed.** `MeleeEnemy.die()` and `ProjectileEnemy.die()` call
  `get_parent().remove_child(self)` without `queue_free()`, so every killed enemy stays in memory
  as an orphan node until the game quits.
