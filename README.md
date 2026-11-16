# Infinite Labyrinth

A top-down dungeon crawler built with Godot 4.7 (Compatibility renderer).

## Running

Open `project.godot` in Godot 4.7 and press **Run**. The main scene is `src/ui/menus/Boot.tscn`,
which starts a new run on floor 1 (coins and upgrades carry over) and loads the generated dungeon (`src/world/Overworld.tscn`).

Progress (floor, coins, upgrade levels) lives in `user://save.cfg`, read and written through
the `SaveData` autoload.

## Room creator

Press **F1** on the title screen to open the room creator. It starts with a blank 13x13 room.
Pick a tool on the left (or press 1-8), then left-click or drag on the floor to paint pitfalls,
and stalagmites, or click to place goblins, knights, wizards and switches; right-click
erases. **Play** (F5) builds the room on its own to try it out, with every door shut; F1 (or
dying) goes back to the editor with the design intact. **Export** writes the design as a
plain-text grid to a `room_designs` folder and copies it to the clipboard, ready to be turned
into a scene in `src/world/rooms/`. Run from source, the folder is in the project; in an
exported build it sits beside the game's executable (or in the user data folder if that one
can't be written to). **Open folder** opens it.

## Smoke test

`tools/smoke_test.gd` loads every script and scene under `src/`, then boots the game headless
and runs it for 240 physics frames. It exits with code 1 and lists each unique error if anything
was logged:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/smoke_test.gd
```

Run it after every change, then playtest.

## Code style

Scripts follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and are statically typed. The `untyped_declaration` warning is on, so the editor flags any
variable, parameter or return type left untyped.

## Known bugs

See [BUGS.md](BUGS.md).

## Layout

```
assets/        sprites, sfx, music, fonts (assets/sfx/unused holds unreferenced duplicates)
src/autoload/  SaveData (save file), Game (coins, keys, game-wide signals and references to
               the player, camera and rooms), Music (dungeon and boss themes) and Juice
               (hit-stop, screen shake, sound pitch variation, flashes and particle bursts)
src/core/      Constants (room ids, grid size, physics layers) and Direction helpers
src/player/    player scene and script
src/enemies/   enemy scenes; Enemy is the base class for MeleeEnemy, RangedEnemy and Boss
src/projectiles/  arrows, fireballs and the boss laser, all one Projectile script
src/objects/   chests, switches, room detection and the fade-out void
src/effects/   flash shader, floor stains and coin pickups used by Juice
src/world/     floor layout (WorldGenerator), building it (Overworld), room script (Room), camera
  rooms/       random rooms (every .tscn here is picked up automatically)
  keyrooms/    rooms holding the three keys
  special/     start, end and boss rooms
  tiles/       TileMap scenes used by rooms
src/editor/    room creator (RoomEditor), its design model and export (RoomDesign) and the
               blank room it paints on
src/ui/        HUD widgets and menus (Boot is the main scene)
src/audio/     enemy death sound players
tools/         headless smoke test
```
