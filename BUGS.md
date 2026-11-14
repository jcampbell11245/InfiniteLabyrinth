# Known bugs

Bugs found during the Godot 4 refactor. The refactor keeps current behaviour on purpose,
so these are left as-is and fixed in a separate bugfix pass afterwards.

## Gameplay

- **Respawning plays a missing animation.** After a pitfall, `Player._on_respawn_cooldown_timeout`
  calls `take_damage(0.5, "none", true)`, which plays `damage_none`. That animation doesn't
  exist, so Godot logs an error and the sprite keeps its previous animation.
- **Being knocked into a pit replays the hit on respawn (GitHub #26).** The issue reports the
  damage animation and hit sound playing when the player respawns after an enemy knocks them into
  a pit. The muted `take_damage` call above explains the animation but not the sound, so there may
  be a second cause in the knocked-into-a-pit case. Not reproduced yet. Knockback works again
  now, so hits can push the player into pits; worth checking this one next.
- **The hit sound plays on after death (GitHub #24).** `Player.die()` pauses the tree, which
  pauses the `Hit` AudioStreamPlayer mid-sound instead of stopping it. When `GameOver` unpauses
  before the upgrade menu, the rest of the sound plays.
- **The end-room key door doesn't block the player (GitHub #27).** With fewer than 3 keys, the
  doorway's `Tiles` cell (13, 8) in `EndRoom.tscn` uses source 2, which has no collision shape. The
  `Top` cell above it does collide, but on physics layer 9, which isn't in the player's collision
  mask (layers 1, 2 and 8). Nothing else blocks the doorway, so the player walks straight through.
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
- **Camera drifts 3px per column.** Rooms are placed 264px apart (`Constants.ROOM_SIZE.x`),
  but `CameraRig` and `Player.start_transition` step 261px (`Constants.LEGACY_ROOM_WIDTH`). By the
  last column the camera is 15px off-centre. `start_transition` also uses the grid formula for the
  end and boss rooms, so the direction it picks there can be wrong.

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
