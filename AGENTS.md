# Working on Infinite Labyrinth

Instructions for AI coding agents (and people) changing this repository. Read this first,
then [README.md](README.md) for what the game is, how to set up Godot and how to run it.

## Before you change anything: claim the work

Every change except the project owner's (**jcampbell11245**) is made on a feature branch
and tracked in a GitHub issue, so two people never do the same work. The full procedure
is the **make-change** skill, [.claude/skills/make-change/SKILL.md](.claude/skills/make-change/SKILL.md);
follow it step by step, whatever agent you are. In short:

1. Ask the developer for a **branch name** and **what they're doing**, if they haven't said.
2. Look for an open issue covering that work. If one exists and **someone else is assigned,
   stop**: tell the developer who has it and don't start. If it's unassigned, assign the
   developer. If there's no issue, create one assigned to them.
3. Branch from an up-to-date `origin/master`, make the change, run the checks, push, and
   open a pull request whose description says `Closes #<issue>`.

`master` is protected: a pull request can only merge once **Smoke test**, **Tests** and
**Linked issue** pass (the last checks the PR closes an open issue assigned to its author),
the branch is up to date with `master`, and someone else has approved it.
The owner may commit to `master` directly and is exempt from the issue rule.

Never close, reassign or edit other people's issues, and never push to someone else's
branch, unless the developer you're working for asks and it's theirs to change.

## Setup

Follow [README.md → Setup](README.md#setup): Godot **4.7.2** exactly (other versions
rewrite scene files), with the `GODOT` environment variable pointing at its executable
(the `_console.exe` one on Windows), plus `git` and the GitHub CLI `gh`, logged in. On a
fresh clone run `"$GODOT" --headless --path . --import` once before anything else.

## Checks: run them after every change

```bash
tools/check.sh            # import, headless smoke test, automated tests (what CI runs)
tools/check.sh tests time # just the tests whose file name contains "time"
```

- **Smoke test** (`tools/smoke_test.gd`): loads every script and scene under `src/`, boots
  the game and runs 240 frames; fails on any error logged.
- **Tests** (`tools/run_tests.gd`): every `tools/tests/test_*.gd`. Add or update a test when
  you change rules that can be checked without looking at the screen (damage, timers,
  layout generation, save data, tuning). See `tools/tests/test_case.gd` for the helpers;
  `boot_floor()` starts a real floor, and tests may `await`.

Headless runs use a dummy renderer: they catch script and scene errors but draw nothing,
and some things behave differently there (the title screen's background room preload is
skipped headless because the dummy renderer isn't thread-safe). So:

- **Visual changes** (HUD, menus, art, effects): take screenshots in a real window and
  look at them before calling the change done:
  `"$GODOT" --path . -s res://tools/screenshot.gd -- /tmp/shot [hurt|upgrades] [frames]`.
  Write screenshots outside the repo.
- **Threading or loading changes**: also run the smoke test without `--headless` once.
- **Sounds and game feel** can't be checked by an agent. Say so plainly when you report
  back, and ask the developer to listen or playtest.

Report honestly: say what passed, what you looked at, and what is not verified (not
playtested, not heard, not checked on another OS).

## How the code is organised

See README → Layout for the folder map. The parts you'll touch most:

- **`src/autoload/Tuning.gd`** holds every gameplay number. Don't hard-code a balance value
  in game code: add a `var` here with a comment (units, what it does) and a row in `FIELDS`
  (`[category, key, label, min, max, step, where it used to live]`) so the F2 debug menu can
  change it live. Read it as `Tuning.<name>` where it's used, so changes apply at once.
- **`Game`** (signals and references to the player, camera, rooms), **`SaveData`** (the save
  file: add a field to `load_from_disk`, `save` and `reset` together; old saves must still
  load), **`Juice`** (hit-stop, slow motion, shake, flashes, particle bursts, sound pitch
  variation), **`Music`**.
- **Enemies**: `Enemy` is the base; `MeleeEnemy` (goblin, knight families), `RangedEnemy`
  (wizard), `Caster` (warlock, necromancer), `Boss`. Melee turns and group rushes are shared
  through `AttackCoordinator`, one per room.
- **Rooms**: every `.tscn` in `src/world/rooms/` is picked up by `WorldGenerator`, which
  caches loaded room scenes for the session; the room creator (F1 on the title screen)
  exports designs to `room_designs/` that get turned into room scenes.
- **HUD**: `src/world/GameCamera.tscn` (HudLayer is scaled 5×, so HUD units are 5 screen
  pixels; the screen is 376 units across) and the scripts in `src/ui/hud/`.

## Assets

Every asset in the finished game is either **hand made** or from an **open-source library**
whose licence allows it. That covers sprites, textures, tiles, icons, animations, sound
effects, music and fonts. It doesn't cover work done in code or simple edits of existing
assets:

- particle effects, tints, flashes and other shader or code-drawn effects;
- slices, flips, crops and recolours of existing sprites;
- sounds that are pitched, reversed, filtered or spliced versions of existing sounds.

A change often needs an asset before the real one exists. When it does, make a **temporary
placeholder** and use it, so the work isn't blocked. You can draw it, generate it by
script, or reuse another asset tinted or scaled. Then, in the same change, **list it in
[PENDING_ASSETS.md](PENDING_ASSETS.md)** with its name, what it's used for, and a preview: a
PNG for still art, a GIF for an animation, or a link to the sound file. Previews go in
`docs/pending_assets/`. Say in the pull request which placeholders you added. An asset you
made yourself (by AI, script or synthesis) is always a placeholder: never record it as
final art.

When a real asset replaces a placeholder, delete its row and preview from
PENDING_ASSETS.md, and record where the real one came from. For a library asset, that's its
licence and link. For a hand-made one, say who made it. Sounds go in
`assets/sfx/SOURCE.txt`, everything else in the PR and commit message.

## Releases

To publish a new version, follow the **make-release** skill,
[.claude/skills/make-release/SKILL.md](.claude/skills/make-release/SKILL.md). It asks whether the
update is major, moderate or minor (unless the developer has said), and builds from an
up-to-date `master` after `tools/check.sh` passes. It exports and zips every preset with
`tools/export_builds.sh`, and drafts the notes in the style of
[release-notes-style.md](.claude/skills/make-release/release-notes-style.md) for the
developer to approve. Then it creates the GitHub release with the zips attached.

## Conventions

- **GDScript**: follow the official style guide and type everything statically (the
  `untyped_declaration` warning is on). Use `class_name` for shared classes, named
  constants for magic numbers, and keep functions short.
- **Comments explain why**, in plain sentences: a paragraph at the top of each script
  saying what it does and how it fits in, and a line above anything non-obvious. Match the
  surrounding style; don't narrate the code.
- **Time**: hit-stop and slow motion change `Engine.time_scale`. UI animations and anything
  that must keep real time use `create_tween().set_ignore_time_scale()` or
  `get_tree().create_timer(t, true, false, true)`; menus that run while paused need
  `process_mode = PROCESS_MODE_ALWAYS`.
- **Scene files** (`.tscn`): editing them as text is fine for small changes (positions,
  properties, removing nodes), but keep each node's `unique_id`, remove an
  `ext_resource` when nothing uses it any more, and run the smoke test after. Prefer the
  Godot editor for anything structural. Don't let a different Godot version re-save them.
- **Line endings are LF** (`.gitattributes`). Scripts that rewrite files must keep them.
- **Assets**: follow [Assets](#assets) above. Reuse what exists before adding. A new or
  derived sound gets a line in `assets/sfx/SOURCE.txt` saying where it came from (licence)
  or how it was made. Keep pixel art on whole pixels; when you edit art, say so in the PR.
- **Docs**: update README.md when behaviour a player or developer would notice changes
  (controls, room creator, debug menu, setup), and BUGS.md when you find or fix a bug.
- **Don't commit** `builds/` (exports), `.godot/`, screenshots of your own checks, or
  profiling scripts. Throwaway scripts go in a temp folder, not the repo.
- **Commits**: one logical change each, a short plain-English subject in the style of
  `git log` (e.g. "Wizards in a room take turns casting"), and a body saying what changed
  and why when it isn't obvious. Agents add their `Co-Authored-By:` trailer.
- **Pull requests**: say what changed, how you checked it (which checks, screenshots for
  visual changes) and what still needs a human (playtest, listening), and end the
  description with `Closes #<issue>`.
