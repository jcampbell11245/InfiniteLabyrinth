# Infinite Labyrinth

A top-down dungeon crawler built with Godot 4.7 (Compatibility renderer).

## Running

Open `project.godot` in Godot 4.7 and press **Run**. The main scene is `src/Starting.tscn`,
which resets the save data and loads the generated dungeon (`src/scenes/Overworld.tscn`).

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
