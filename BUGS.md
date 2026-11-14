# Known bugs

Bugs found during the Godot 4 refactor. The refactor keeps current behaviour on purpose,
so these are left as-is and fixed in a separate bugfix pass afterwards.

## Gameplay

- **Pitfalls deactivate the wrong room.** `Player._pitfall_room()` returns Overworld's child
  `current_room + 3`, but generated rooms start at child index 6. Enemies in the room you fell in
  keep attacking while you're invisible; a room three ids earlier gets paused instead. In the start
  and end rooms (ids 60/61) the index is out of range, so the fall handler errors out before it
  starts the respawn timer and the player stays invisible. Neither room has pits today.
- **Respawn points are wrong in the start, end and boss rooms.** `Player._update_respawn_point`
  works out the room's position with the grid formula, which gives nonsense for ids 60–62.
  None of those rooms has pits today, so it never shows.
- **Player knockback does nothing.** `Player.knockback` is never set (the line in `take_damage`
  was commented out in Godot 3), so the knockback step in `_physics_process` is inert.
- **Upgrades never persist between launches.** `Boot.gd` calls `SaveData.reset()` every time
  the game starts, wiping floor, coins and all four upgrades.
- **The floor number never goes up.** Nothing increments `SaveData.floor_number`, so every
  floor is floor 1 and the coin multiplier never grows. Dying sets it to 1, then the upgrade
  menu's Continue writes the Overworld's old `floor_number` back over it.
- **Respawning plays a missing animation.** After a pitfall, `Player._on_respawn_cooldown_timeout`
  calls `take_damage(0.5, "none", true)`, which plays `damage_none`. That animation doesn't
  exist, so Godot logs an error and the sprite keeps its previous animation.
- **Coin drop formula has precedence bugs.** The original MeleeEnemy used
  `10 * floor * 1+((looting + 1 /10))`, which is `10 * floor + looting` (`1 / 10` is 0), and the
  wizard used `1+((looting + 1)/10)`, so the two scale differently. Kept as `Enemy._looting_bonus()`
  and its `RangedEnemy` override.
- **Wizard crits are not random per run.** `RangedEnemy._roll_critical` creates a
  `RandomNumberGenerator` without calling `randomize()`, so it always rolls the same first number.
- **Wizards back away past the top and bottom walls.** In `RangedEnemy._can_retreat`, the
  vertical limits look swapped: backing down is checked against the top bound and backing up
  against the bottom one, so neither stops the wizard before the wall.
- **The boss never idles in its room.** In `Boss.animate`, the idle branch had the same
  condition as the slash branch before it, so it could never run. The dead branch was removed.
- **Room 0 is treated as entered at startup.** `Player.current_room` starts at 0, so before the
  start room's detector fires, room 0 fades in and draws its lock tiles. They stay until room 0
  is cleared. Kept by `Overworld._ready` emitting `room_entered` for room 0.
- **The camera isn't centred the same way in every room.** Measured from each room's position,
  `CameraRig` aims at (341, 302) in the start and end rooms, (325, 302) in the boss room and
  (338, 301) in grid column 0, drifting further in later columns (next entry).
- **Camera and respawn drift 3px per column.** Rooms are placed 264px apart
  (`Constants.ROOM_SIZE.x`), but `CameraRig`, `Player._update_respawn_point` and `Player.start_transition`
  step 261px (`Constants.LEGACY_ROOM_WIDTH`). By the last column the camera is 15px off-centre
  and respawn points are 15px off their tiles.

## Rooms (`Room.gd`)

- **Transition detectors are always placed.** Conditions like
  `get_cell_source_id(...) == 1 || 20 || 21` and `... == 2 || 3` are always true because the
  bare numbers are truthy, so detectors are added on the top and left walls of every room
  regardless of tiles.
- **The left-door detector checks the right-door lock cell.** The `(8, 13)` detector condition
  reads `$Locks.get_cell_source_id(0, Vector2i(18, 13))`.
- **Decoration variants overwrite each other.** The original `if variant < 60 / < 64 / < 66`
  chain wasn't `elif`, so later branches overwrote earlier ones and decorations 0 and 1 never
  appear. `Room._add_decorations` keeps the effective result (2, or 3 on the top roll).
- **Skipped tiles from the Godot 4 conversion.** 318 cells whose tile ids no longer existed in
  their Godot 3 tilesets were dropped during the tile-data restore (mostly `Top` id 5,
  `Pitfalls` ids 1–2, `Tiles` ids 41–43). Godot 3 drew nothing for these either, but it's worth
  checking that no room relied on them for collision.
- **Per-room collision overrides were lost.** In Godot 3, BossRoom's (formerly B1) `TopWalls` used collision layer 257
  and R1/R32 changed `Top`'s mask on the node. Godot 4 keeps collision on the shared TileSet, so
  those rooms now use the default tileset layers.

## Engine / cleanup

- **Physics state changed during collision callbacks.** Enemies set `hurtbox.disabled = true`
  inside the hurtbox signal, which Godot reports as "Can't change this state while flushing
  queries". It should use `set_deferred`.
