---
name: make-release
description: Use when a developer wants to publish a new release of Infinite Labyrinth (a new version, "cut a release", "ship builds"). Works out the next version number (major, moderate or minor), exports every preset in export_presets.cfg, zips each build folder on its own, drafts release notes in the project's style, and creates the GitHub release with all the zips attached.
---

# Make a release of Infinite Labyrinth

A release is a GitHub release on `jcampbell11245/InfiniteLabyrinth`. It has a tag named
`v<version>`, the title `Version <version>`, a bulleted list of what changed since the
last release, and one zip per export preset attached (`InfiniteLabyrinth-Windows64.zip`,
`-Windows32`, `-Linux64`, `-Linux32` and `-MacOS` today). Releases are always built from
`master` as it is on GitHub. Follow these steps in order.

## 1. Check the tools

```bash
git --version && gh --version && "$GODOT" --version
gh auth status
```

You also need Godot's **4.7.2 export templates** (README → Setup, the note under "Clone and
import"). If any of this is missing, help the developer set it up first.

## 2. Start from an up-to-date master

```bash
git status --short          # must be clean; if not, ask what to do with the changes
git fetch origin --tags
git switch master
git merge --ff-only origin/master
tools/check.sh
```

Every check must pass. If any fail, stop and tell the developer: don't release a broken
master.

## 3. Pick the version number

Find the last release:

```bash
gh release list --limit 1 --json tagName,publishedAt
```

Ignore a leading `v` (one older tag, `2.4.2`, doesn't have one). Then ask the developer
whether this is a **major**, **moderate** or **minor** update, unless they've already said:

| Update | Bumps | Example from 2.4.2 |
| --- | --- | --- |
| Major | first number; the others reset to 0 | 3.0.0 |
| Moderate | second number; the last resets to 0 | 2.5.0 |
| Minor | last number | 2.4.3 |

Don't pick for them. Make sure the new tag isn't taken already:
`gh release view v<version>` should fail.

## 4. Draft the release notes

List what's changed since the last release:

```bash
git log --no-merges --format='%h %s%n%b' <last tag>..HEAD
gh pr list --state merged --base master --limit 50 --json number,title,body,mergedAt \
  --search "merged:>=<last release's publishedAt date>"
```

Read the commits and PRs, and work out what changed **for someone playing the game or
using its tools** (the room creator, the debug menu). Then write the notes following
[release-notes-style.md](release-notes-style.md). Save them to a temporary file outside
the repo.

Show the draft to the developer, and wait for them to approve it or change it before you go
on. The notes are public once the release is out.

## 5. Export and zip the builds

```bash
tools/export_builds.sh
```

The script reads every preset in `export_presets.cfg` and empties each preset's output
folder in `builds/`. It then exports each preset with `--export-debug` (every release so
far has been a debug export, so the F2 debug menu works) and zips each folder on its own,
flat, into `builds/InfiniteLabyrinth-<folder>.zip`. A preset added later is picked up
automatically.

Then check:

- There's one zip per preset, each tens of megabytes, as in past releases. A zip that's
  far smaller than the same zip in the last release means something is wrong.
- `git status --short` is clean. Importing can make Godot re-save a scene file in a
  slightly different format. If that happens, put it back with `git restore <file>`, and
  never commit it as part of a release.

## 6. Create the release

```bash
gh release create v<version> builds/InfiniteLabyrinth-*.zip \
  --target "$(git rev-parse HEAD)" \
  --title "Version <version>" \
  --notes-file <notes file>
```

`--target` with the commit you exported makes the tag point at exactly what's in the zips.
Then confirm it worked:

```bash
gh release view v<version> --json url,tagName,assets --jq '{url, tagName, assets: [.assets[].name]}'
```

Every zip should be listed. Give the developer the release's URL. Tell them the builds
haven't been run on any platform: an agent can't play them, so someone should start at
least one build before telling other people about the release.

## If something goes wrong

- **The export fails:** usually the export templates are missing or the wrong version.
  Godot says which template it was looking for.
- **The release was created with something wrong** (wrong notes, a missing zip): fix it in
  place. Use `gh release edit v<version> --notes-file <file>` for the notes, and
  `gh release upload v<version> <zip> --clobber` for a zip. Only delete a release
  (`gh release delete v<version> --cleanup-tag`) if the developer asks.
