# Writing release notes

Release notes are a plain bulleted list of what changed, written for the people playing
the game. Nothing else goes in: no headings, no intro, no sign-off. Keep the bullets
simple: when in doubt, make a bullet shorter and plainer.

## The rules

- **One change per bullet, one line each.** Use `- ` bullets, sentence case, and no full
  stop at the end.
- **Start with a past-tense verb.** The ones the notes use most are *Added*, *Fixed*,
  *Removed*, *Adjusted*, *Increased*, *Reduced*, *Made*, *Changed*, *Improved*, *Updated*,
  *Replaced* and *Revamped*. A short noun phrase is fine when it reads better, e.g. "Timing
  adjustments".
- **Say what the player notices, not how the code does it.** Write "Made wizards take turns
  shooting", not "Added a turn queue to RangedEnemy". Leave out numbers unless they're the
  point ("Reduced key requirement to 2").
- **Keep it short.** Most bullets are 3-8 words. Add a short clause or a bracket only when
  the bullet doesn't make sense without it, e.g. "(requires a roll to avoid, indicated with
  a red star)".
- **Group a big feature.** Give it a parent bullet, with its parts as sub-bullets indented
  two spaces. For example "Added enemy families", with one sub-bullet per family, or "Room
  creator changes". Use sub-bullets only for real groups, and never go more than one level
  deep.
- **Order:** new features first, then changes and balance tweaks, then fixes.
- **Fixes say what was broken:** "Fixed room creator crashing game", "Fixed doorway
  triggers". "Fixed knights" is fine when the fix was a broad repair.
- **Include tool changes** that a developer or tester would notice (room creator, debug
  menu). **Leave out internal work**: refactors, tests, CI, docs, code review tidy-ups.
- **Mention placeholder assets** when they're new or replaced ([PENDING_ASSETS.md](../../../PENDING_ASSETS.md)),
  e.g. "New temporary sound effects for charged arrows" or "Replaced temporary status
  icons with new sprites".
- **A single change** is still a bullet: `- Fixed room creator crashing game`.

## Examples from past releases

Version 2.4.1, a typical release:

```markdown
- Removed health and made damage reduce time
- Improved load times
- Made wizards take turns shooting
- Adjusted wizard melee attack
- Changed knight heavy attack sound
- Increased chance for group rushes
- Reduced arrow drop rate
```

Version 2.4.0, with grouped features:

```markdown
- Added enemy families
  - Trolls that steal coins from the player
  - Orcs that are twice as large as a standard goblin
  - Dual knights that slash twice and don't have a shield
  - Warlocks that give random status effects
  - Necromancers that revive enemies
- Revamped wizards
  - Made them only have 1 shot and made it a homing shot
  - Added a weak clashable melee attack
- Added the charged spin attack and group rushes that require it to counter
- Updated room editor ui to use tabs and icons
- Replaced temporary status icons with new sprites
```

## Turning commits into bullets

| Commit or PR | Bullet |
| --- | --- |
| "Wizards in a room take turns casting" | Made wizards take turns shooting |
| "Room scenes are cached and preloaded from the title screen" | Improved load times |
| "Add title screen audio options" + "Add audio options to the pause menu" | Added audio options to the title screen and pause menu |
| "Enemies hauled back slower, and tear free of paste on the third edge" | Adjusted thermal paste |
| "Address review feedback on audio options" | (leave out, it's part of the audio options bullet) |
| "Track placeholder assets in PENDING_ASSETS.md" | (leave out, it's internal) |
