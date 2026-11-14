# Infinite Labyrinth

A top-down dungeon crawler built with Godot 4.7 (Compatibility renderer).

## Running

Open `project.godot` in Godot 4.7 and press **Run**. The main scene is `src/ui/menus/Boot.tscn`,
which resets the save data and loads the generated dungeon (`src/world/Overworld.tscn`).

Progress (floor, coins, upgrade levels) lives in `user://save.cfg`, read and written through
the `SaveData` autoload.

## Smoke test

`tools/smoke_test.gd` loads every script and scene under `src/`, then boots the game headless
and runs it for 240 physics frames. It exits with code 1 and lists each unique error if anything
was logged:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/smoke_test.gd
```

Run it after every change, then playtest.

## Known bugs

See [BUGS.md](BUGS.md).

## Layout

```
assets/        sprites, sfx, music, fonts (assets/sfx/unused holds unreferenced duplicates)
src/autoload/  SaveData (save file), Game (references to the player, camera, HUD and rooms)
               and Music (dungeon and boss themes)
src/core/      Constants (room ids, grid size, physics layers) and Direction helpers
src/player/    player scene and script
src/enemies/   enemy scenes; Enemy is the base class for MeleeEnemy, RangedEnemy and Boss
src/projectiles/  arrows, fireballs and the boss laser, all one Projectile script
src/objects/   chests, switches, room detection and the fade-out void
src/world/     floor layout (WorldGenerator), building it (Overworld), room script (Room), camera
  rooms/       random rooms (every .tscn here is picked up automatically)
  keyrooms/    rooms holding the three keys
  special/     start, end and boss rooms
  tiles/       TileMap scenes used by rooms
src/ui/        HUD widgets and menus (Boot is the main scene)
src/audio/     enemy death sound players
tools/         headless smoke test
```
