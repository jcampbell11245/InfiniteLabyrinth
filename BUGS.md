# Known bugs

Bugs found during the Godot 4 refactor. The refactor keeps current behaviour on purpose,
so these are left as-is and fixed in a separate bugfix pass afterwards.

## Gameplay

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
