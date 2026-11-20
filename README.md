# Infinite Labyrinth

A top-down pixel-art dungeon crawler made with **Godot 4.7.2** (Compatibility renderer).
Fight through a generated floor of rooms against the clock, collect three keys to open the
end room, and spend your coins on upgrades between floors.

- [Playing](#playing) · [Setup](#setup) · [Running](#running) · [Checks](#checks) ·
  [Contributing](#contributing) · [Tools](#tools) · [Exporting builds](#exporting-builds) ·
  [Layout](#layout)
- Working on the code? Read [AGENTS.md](AGENTS.md) too: it's the guide for AI agents and
  people alike.

## Playing

Each floor is a 5×6 grid of rooms between a start room and an end room. Three key rooms
hold keys that open the end room; a boss waits behind a door in the start room.

**There's no health: you have time.** Each floor starts with a time limit (longer with the
Time upgrade). Getting hit takes time off it, more for harder hits, and the run ends when
it reaches 0:00. Between floors, and after a game over, coins buy upgrades: **Luck**
(critical hits), **Time** and **Looting** (coins per kill).

Combat is built on reading enemy attacks: a glint on an enemy's weapon means it's about to
strike. Swing as it glints to **parry** and stun it; swing too early and you're the one
staggered. A red glint can't be parried: roll behind it. Hold the sword button to charge
a **spin attack**, which also breaks up group rushes.

Choose **Options** on the title screen or in the pause menu to set persistent Music and SFX
volume separately. In the pause menu, the pause key or **Back** returns to the pause buttons.

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD or arrow keys | D-pad |
| Sword (hold to charge a spin) | J or Z | X / Square |
| Bow (hold to charge) | K or X | Y / Triangle |
| Roll | Space | RB / R1 |
| Pause | Esc | Start |
| Room creator (title screen) | F1 | |
| Debug menu (debug builds) | F2 | |

## Setup

Everything here can be run as written by a person or an agent. You need **Godot 4.7.2**
exactly (a different version re-saves the scene files differently), **git**, and the
**GitHub CLI** (`gh`) for issues and pull requests.

### 1. Install Godot 4.7.2 and set `GODOT`

The project's scripts and docs call Godot through the `GODOT` environment variable. On
Windows point it at the **console** executable, so command-line runs print their output.

**Windows** (PowerShell):

```powershell
$v = "4.7.2"
Invoke-WebRequest "https://github.com/godotengine/godot-builds/releases/download/$v-stable/Godot_v$v-stable_win64.exe.zip" -OutFile "$env:TEMP\godot.zip"
Expand-Archive "$env:TEMP\godot.zip" -DestinationPath "$env:LOCALAPPDATA\Godot" -Force
[Environment]::SetEnvironmentVariable("GODOT", "$env:LOCALAPPDATA\Godot\Godot_v$v-stable_win64_console.exe", "User")
```

Open a new terminal afterwards so it sees `GODOT`. Use `Godot_v4.7.2-stable_win64.exe`
(without `_console`) from the same folder to open the editor.

**macOS**:

```bash
curl -fL -o /tmp/godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip
unzip -q /tmp/godot.zip -d /Applications
echo 'export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"' >> ~/.zshrc && source ~/.zshrc
```

**Linux** (x86-64):

```bash
mkdir -p ~/.local/godot && cd ~/.local/godot
curl -fL -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q godot.zip && rm godot.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64
echo 'export GODOT="$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64"' >> ~/.bashrc && source ~/.bashrc
```

Check it: `"$GODOT" --version` should print `4.7.2.stable.official...`. (In PowerShell:
`& $env:GODOT --version`.)

### 2. Install git and the GitHub CLI, and log in

- Windows: `winget install --id Git.Git` and `winget install --id GitHub.cli`
- macOS: `brew install git gh`
- Linux: your package manager's `git`, and `gh` from <https://cli.github.com>

Then log in (a person has to do this step; it opens a browser):

```bash
gh auth login
```

### 3. Clone and import

```bash
git clone https://github.com/jcampbell11245/InfiniteLabyrinth.git
cd InfiniteLabyrinth
"$GODOT" --headless --path . --import
tools/check.sh
```

The import builds Godot's `.godot/` cache (it isn't committed); `tools/check.sh` should end
with **All checks passed.** On Windows run `tools/check.sh` from Git Bash.

To export builds you also need the export templates: in the editor, **Editor → Manage
Export Templates → Download and Install** (they're also at
`https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`).

## Running

Open the project in the editor (`"$GODOT" --editor --path .`, or open `project.godot`
from the Godot project manager) and press **Run** (F5). Or run it straight from a terminal:
`"$GODOT" --path .`

The main scene is the title screen (`src/ui/menus/TitleScreen.tscn`). **Start** goes through
`Boot`, which starts a run on floor 1, to the generated floor (`src/world/Overworld.tscn`).
While the title screen is up, the room scenes load in the background so the run starts
quickly.

Progress (floor, coins, upgrade levels) is saved in `user://save.cfg` through the
`SaveData` autoload. Delete it to start over.

## Checks

Pull requests can only merge into `master` when three checks pass (see
`.github/workflows/`), the branch is up to date with `master`, and another developer has
approved it. Run the first two checks yourself before pushing:

```bash
tools/check.sh
```

- **Smoke test**: `tools/smoke_test.gd` loads every script and scene under `src/`, boots
  the game headless and runs 240 physics frames. It fails if anything logs an error.
- **Tests**: `tools/run_tests.gd` runs every `tools/tests/test_*.gd` (floor generation,
  damage and the timer, the tuning table, room scenes). Run some with
  `tools/check.sh tests <part of a file name>`. New tests extend `tools/tests/test_case.gd`.
- **Linked issue**: the pull request's description must close an open issue its author is
  assigned to (`Closes #12`). The owner's pull requests are exempt.

Headless runs draw nothing, so check visual changes with `tools/screenshot.gd` (see
[Tools](#tools)) and playtest.

## Contributing

1. **Claim the work.** Find the GitHub issue for what you want to do. If someone else is
   assigned, it's theirs: pick something else or talk to them. If it's unassigned, assign
   yourself; if there's no issue, create one and assign yourself.
2. **Branch** from the latest `master`: `git fetch origin && git switch -c <branch> origin/master`.
3. **Change, then check**: `tools/check.sh`, screenshots for visual changes, a playtest.
4. **Open a pull request** into `master` that says `Closes #<issue>`, get the checks green,
   and ask a teammate for the one approving review it needs.

Only the project owner commits to `master` directly. AI agents do all of this through the
`make-change` skill ([.claude/skills/make-change/SKILL.md](.claude/skills/make-change/SKILL.md));
the conventions are in [AGENTS.md](AGENTS.md). Report bugs as issues, or in
[BUGS.md](BUGS.md) alongside a fix.

## Tools

### Room creator

Press **F1** on the title screen to open the room creator. It starts with a blank 13x13 room.
Pick a tool from the panel on the left (Eraser and Select on top, then the **Tiles**,
**Traps** and **Enemies** tabs of icons), then left-click or drag on the floor to paint
pitfalls, stalagmites and special tiles, or click to place enemies (goblins, trolls, orcs,
knights, dual knights, wizards, warlocks, necromancers, wyrms, wyverns) and switches;
right-click erases.
Hover a tile's button to see what it does (see [Special tiles](#special-tiles)). A goblin, knight or dragon you place, or click with the **Select** tool, shows its detection
radius as a circle (default 64 px); drag the circle's edge to resize it. The shaded half is
the side it watches, since enemies can't see behind themselves. Wizards have no radius: they
react to the player anywhere in the room. In room scenes the value is each enemy's
`detection_radius`.

**Facing** sets which way the selected goblin, knight or dragon faces when the room starts: **Up**,
**Down**, **Left**, **Right** (the default) or **Auto**, which turns it to face the player as
they come into the room, so it looks at the door they used (unless it has already noticed
them). The editor sprite turns to match, an Auto enemy is marked "auto", and the shaded half
of its detection circle follows the facing. In room scenes this is each enemy's
`starting_direction` (`"auto"` for Auto).

**Roaming** sets what the selected goblin or knight does before it notices the player:
**None** (stands still, the default and what every existing room uses), **Path** or **Area**.
Picking Path or Area switches to the Select tool. For a path, click or drag on the floor to
draw it from the enemy outwards (dragging back over the last point takes it off), and
right-click a point to remove it; the enemy walks it there and back, pausing at each end.
Click the enemy itself to finish the path back where it started: a closed path is a loop
the enemy walks round the same way, pausing each time it's back at the start.
For an area, drag the box's edges or corners to resize it; the enemy wanders between random
spots inside it. Seeing the player, being hit (arrows included) or being alerted by another
enemy ends roaming and it fights as usual. Wizards can't roam, since they react to the
player anywhere in the room, and nor can dragons, which hover where they start. In room
scenes these are each enemy's `roam_mode`, `roam_path` and `roam_area`;
roaming speed and pauses are in `Tuning.gd` (the debug menu's AI tab).

**Tileset** switches the preview (and the play-test) between each floor's art, so a room can
be checked on floor 2's tiles. **Floors** is a dropdown checklist of floors 1-10 that the room
can appear on (floors after 10 follow Floor 10), with Every floor and No floors to set them
all at once. In room scenes this is the room's `floors` flags; all existing rooms appear on
every floor. If too few rooms are allowed on a floor to fill it, some appear twice. Ctrl+Z undoes and Ctrl+Y redoes, or use the Undo and Redo buttons. Clear opens a menu to
wipe everything, just the enemies, or just the tiles (pitfalls and stalagmites). Choose what clears the room: None (the default; the doors never lock), beating its enemies, or hitting its switches. **Play** (F5) builds the room on its own to try it out, with every door shut; F1 (or
dying) goes back to the editor with the design intact. **Export** writes the design as a
plain-text grid to a `room_designs` folder and copies it to the clipboard, ready to be turned
into a scene in `src/world/rooms/`. Run from source, the folder is in the project; in an
exported build it sits beside the game's executable (or in the user data folder if that one
can't be written to). **Open folder** opens it.

### Special tiles

The room creator's **Tiles** tab has slick floor, slow and speed tiles and four pairs of
teleporters; the **Traps** tab has exposed wires, spikes, cracked floor, pressure plates and
thermal paste. They affect the player and enemies alike. Enemies walk round a trap when the
way round is short, but cut across rather than go far out of their way. A roll protects the
player from spikes and shocks.

| Tile | What it does |
|---|---|
| Exposed wires | Rest, spark as a warning, then go live (with an enemy-style twinkle) and shock whoever is on them. Swing the sword into them while live to break them for good. |
| Pressure plate | Clicks down when stepped on (and pops back up as soon as it's left), then goes live like wires and re-arms. Breaks the same way. |
| Spikes | Hurt on stepping on, and again every second while stood on. Rolling right over them in one roll is safe; a roll that ends on them isn't. |
| Cracked floor | Cracks when stood on, gives way into a pit, then mends. Enemies on it fall. |
| Slick floor | Keeps momentum: speeding up, slowing down and turning all slide. Enemies slide further than the player and keep drifting after they stop. |
| Thermal paste | Holds whoever steps in to within half a tile of it, pulling them back when they stop. Enemies caught in it walk as usual inside that area, run on the spot at its edge, and after a couple of seconds there are slowly hauled back to the middle; the third time they reach the edge they tear free. It never wears off: three rolls break free, counted down by a bar over the player's head. |
| Slow / speed tile | Slower or faster walking, rolling and attacking while on it, with a sound on stepping on and a status icon while there. |
| Teleporter | Sends whoever steps on it, and any arrow, fireball or laser flying over it, to the other square of the same colour and symbol (the next one in reading order, if there are more than two). Step off before using it again. Standing right by one lights up the square it sends to. Going through squashes the square the way it was entered and stretches the far one out. |

Their timings, damage and strengths are in the debug menu's **Tiles** tab (`Tuning.gd`). In a
room scene they're a `SpecialTiles` layer (`src/world/tiles/SpecialTiles.tscn`), painted with
the frames of `assets/sprites/tiles/special_tiles.png` (placeholder art); the room creator's
export lists them in its grid.

### Debug menu

In debug builds (running from the editor or a debug export), **F2** opens the debug menu over
the game and pauses it; F2 or **Close** shuts it again. The **Progress** tab edits the running
floor (coins, keys, arrows, time left, floor, upgrade levels) and has Refill time, Kill
enemies in this room and Next floor buttons. The other tabs edit the gameplay numbers in
`src/autoload/Tuning.gd` (roll, parry window, damage, enemy multipliers, special tiles, timer,
loot, hit-stop, cheats like god mode), which game code reads live. Each row has a **Reset**: Tuning rows go back
to their shipped value, Progress rows to what they were when the menu opened. **Reset all**
resets every row. **Export** writes every Tuning value, changed ones first and marked `*`, to a
`tuning_exports` folder (same locations as the room creator's export) and copies it to the
clipboard. Hover a row's name to see where its value lives in the code. Changed values last
until the game closes; copy the ones you want to keep into the defaults in `Tuning.gd`.

### Screenshots

`tools/screenshot.gd` boots a floor in a window and saves what it shows, for checking HUD,
menu and art changes without playing:

```bash
"$GODOT" --path . -s res://tools/screenshot.gd -- /tmp/shot            # /tmp/shot.png
"$GODOT" --path . -s res://tools/screenshot.gd -- /tmp/shot hurt       # plus two frames after a hit
"$GODOT" --path . -s res://tools/screenshot.gd -- /tmp/shot upgrades   # plus the upgrade menu
```

## Exporting builds

`export_presets.cfg` has presets for Windows (64 and 32 bit), Linux (64 and 32 bit) and
macOS, each writing to its own folder in `builds/` (ignored by git; publish builds as GitHub
releases). In the editor use **Project → Export → Export All**, or from a terminal, for
example:

```bash
"$GODOT" --headless --path . --export-release "Windows Desktop 64 bit"
```

The other preset names are `Windows Desktop 32 bit`, `Linux 64 bit`, `Linux 32 bit` and
`macOS`. Export templates must be installed first (see Setup).

## Code style

Scripts follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and are statically typed. The `untyped_declaration` warning is on, so the editor flags any
variable, parameter or return type left untyped. More conventions are in
[AGENTS.md](AGENTS.md#conventions).

## Known bugs

See [BUGS.md](BUGS.md) and the open issues.

## Layout

```
assets/        sprites, sfx (sources in assets/sfx/SOURCE.txt), music, fonts
src/autoload/  Tuning (every gameplay number, edited live by the debug menu), SaveData (save
               file), Game (coins, keys, game-wide signals and references to the player,
               camera and rooms), Music, Juice (hit-stop, slow motion, screen shake, sound
               pitch variation, flashes and particle bursts), DebugMenu
src/core/      Constants (room ids, grid size, physics layers) and Direction helpers
src/player/    player scene and script, the level timer, curses
src/enemies/   Enemy is the base for MeleeEnemy (goblin and knight families), RangedEnemy
               (wizard), Caster (warlock, necromancer), Wyrm (wyrm and wyvern, flying
               dragons) and Boss; AttackCoordinator takes turns and group rushes
               between a room's enemies; FireballReturner bats fireballs back
src/projectiles/  arrows, fireballs and the boss laser, all one Projectile script
src/objects/   chests, switches, room detection and the fade-out void
src/effects/   flash shader, twinkle, status bars, floor stains and coin pickups
src/world/     floor layout (WorldGenerator), building it (Overworld), room script (Room),
               special tiles (SpecialTiles), camera and HUD (GameCamera)
  rooms/       random rooms (every .tscn here is picked up automatically)
  keyrooms/    rooms holding the three keys
  special/     start, end and boss rooms
  tiles/       TileMap scenes used by rooms (SpecialTiles.tscn: traps and teleporters)
src/editor/    room creator (RoomEditor), its design model and export (RoomDesign) and the
               blank room it paints on
src/ui/        HUD widgets (timer, counters, minimap) and menus (title, boot, pause,
               upgrades, game over)
src/audio/     enemy death sound players
tools/         smoke test, test runner and tests, check script, screenshot tool
.github/       pull request checks (workflows) and the Godot setup they share
.claude/       the make-change skill agents follow
room_designs/  room creator exports waiting to become room scenes
```
