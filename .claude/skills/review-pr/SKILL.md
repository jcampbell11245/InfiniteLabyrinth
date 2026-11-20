---
name: review-pr
description: Use when a developer asks you to review a pull request on Infinite Labyrinth ("review PR 51", "look at #44 again", "check 47"). Checks out the branch, reads the description and the whole diff, judges whether the size of the change is justified, checks the code against AGENTS.md, runs the checks (protecting the developer's save file), takes real-window screenshots of anything visible, reports a verdict with numbered findings, and posts them as inline review comments only when asked. Also covers re-reviewing after the author pushes fixes.
---

# Review a pull request on Infinite Labyrinth

You review for the developer you're working with (usually the owner, `jcampbell11245`);
the pull request is someone else's. You read, run and report. You never push to the
author's branch, never approve, merge or close, and never post anything to GitHub until
the developer says to. Follow these steps in order.

Repository: `jcampbell11245/InfiniteLabyrinth`. Use a temp folder outside the repo (your
scratchpad) for screenshots, scratch scripts and review files.

## 1. Check out the branch

```bash
git status --short                      # must be clean before switching
gh pr checkout <n>                      # or: git switch <branch> && git pull --ff-only
git fetch origin
```

If the working tree isn't clean, look at the change first (`git diff`). If it's a leftover
of a check run (Godot sometimes rewrites `project.godot` or a scene header on import), or
anything you can't explain, **stash it** with a message saying what it is
(`git stash push -m "..." <file>`) rather than discarding it, and tell the developer.

## 2. Read the pull request

```bash
gh pr view <n> --json title,body,author,headRefName,state,mergeable,files,commits
git merge-tree --write-tree --name-only origin/master HEAD   # conflicts with master, if any
```

Note the author, the issue it closes, what it says it does, how it says it was checked, and
what it says still needs a human. Check the issue it closes is open and assigned to the
author (`gh issue view <n> --json assignees,state`).

Then read **the whole diff** (`git diff origin/master...HEAD -- . ':!*.png'`), and read new
scripts in full, not just the hunks. For every changed behaviour, find the code it touches
elsewhere (`grep` callers, signals, scenes that use it) before deciding it's right.

## 3. Judge the size of the change

Always say whether the number of files and lines is justified. Count what's mechanical
(sprite sheets and their `.import` files, one-line edits repeated across scenes) apart
from real code. Say which parts are well placed (shared code pulled out, small hooks in
base classes) and push back where it isn't (one huge script mixing unrelated jobs, a PR
doing several unrelated things). If a repeated edit across many files is the only way to
do it, say so and explain why, and point out the risk (the next file added will miss it)
and how to guard against it (a test).

## 4. Look for problems

Work through these, and only report what you've confirmed in the code:

- **Correctness**: state that isn't reset (timers, "last seen" times, statics that outlive a
  scene), paths that leave the game paused or slowed, signals connected and never
  disconnected, null rooms or players, behaviour that changed by accident in moved code.
- **Interactions with other open PRs and with master**: two PRs editing the same scene or
  script, a node one renames that another looks up, new sound players that miss the `SFX`
  bus, a branch that's behind a fix on master.
- **AGENTS.md rules**: every gameplay number in `Tuning.gd` with a `FIELDS` row; static
  typing; comments that explain why; keep functions short; scene edits keep `unique_id`s;
  sounds in `assets/sfx/SOURCE.txt`; placeholder art and sounds listed in
  `PENDING_ASSETS.md`; art edits mentioned in the PR; README and BUGS.md updated.
- **Tests**: new rules covered; tests restore anything they change; nothing that only
  passes because of test order.
- **Docs and text**: tooltips, README and comments that no longer match the code.
- **Efficiency**: per-frame work that's easy to avoid (building pathfinding where it isn't
  needed, scanning every node every frame for no reason). Only when it's real.

## 5. Run the checks

Back up the developer's save file first. A branch older than the save-file fix on master
(28a3fa1) wipes it when its tests run, and you can't know every branch has it. On Windows
the save is `$APPDATA/Godot/app_userdata/<config/name from project.godot>/save.cfg`.

```bash
cp "$SAVE" "<temp>/save.cfg.backup"
tools/check.sh
cmp -s "$SAVE" "<temp>/save.cfg.backup" || cp "<temp>/save.cfg.backup" "$SAVE"   # and say so
git status --short                       # a check run shouldn't leave changes behind
```

If master has moved on, also run the checks on a **trial merge** in a temporary worktree,
so you know the PR still works with what's merged since:

```bash
git worktree add --detach "<temp>/merge" HEAD
cd "<temp>/merge" && git merge --no-edit origin/master   # in the temp worktree only
"$GODOT" --headless --path . --import; tools/check.sh
cd - && git worktree remove --force "<temp>/merge"
```

## 6. Look at anything visible

For menus, HUD, art, effects, new enemies or tiles, take **real-window** screenshots and
open them yourself; the author's agent often can't. `tools/screenshot.gd` covers a floor;
for anything else write a scratch `extends SceneTree` script in the temp folder that
changes scene, waits some frames and saves `root.get_texture().get_image()`. Load game
classes in it at run time (`load("res://src/editor/RoomDesign.gd")`) rather than by
`class_name`: a `-s` script compiles before the autoloads exist, and naming those classes
fails to compile. To see a room with particular enemies or tiles, build a `RoomDesign`,
set `Overworld.test_design` to it and change to `Overworld.tscn` (the room creator's
play-test).

```bash
"$GODOT" --path . -s "<temp>/shots.gd" -- "<temp>/shot"
```

Check what you see against the description: sizes, spacing, overlaps, focus states
(focused and unfocused controls can use different theme icons), text that fits.

## 7. Report to the developer

Start with a one-line **verdict** (ready, ready after small fixes, needs work). Then:

- **Is this many files justified?** (step 3)
- **Blocking**: conflicts with master, things that stop it merging.
- **Should fix**: bugs, with a concrete failure case and a suggested fix.
- **Your call**: design questions and rule exceptions the developer should decide.
- **Minor**: small cleanups.
- **Checked and fine**: risky areas you looked at and found correct.
- **What I checked**: checks run and their results, screenshots looked at, and what is
  **not** verified (not playtested, sounds not heard, a bug found by reading, not reproduced).

Number the findings so the developer can refer to them. Say plainly when you found
something by reading rather than running it. If you turn out to have been wrong in an
earlier report, correct it. Then ask whether to post the findings as comments.

## 8. Post the comments (only when asked)

Post exactly what the developer agreed to: leave out anything they said to drop, and
word their decisions as decisions ("the owner has decided..."). Questions they left open
are put to the author as questions.

1. Fetch first and use the **current head commit**; authors often push while you review.
   If it moved, read the new commits and recheck your line numbers.
2. Write one review as JSON in the temp folder: `commit_id` (the head SHA), `event`
   `"COMMENT"` (never `APPROVE` or `REQUEST_CHANGES` unless asked), an optional `body` for
   points not tied to a line (conflicts, process), and `comments`, each with `path`, `line`
   (in the head version of the file) and `side` `"RIGHT"`. A line must be part of the diff.
3. Post and check every comment landed on the line you meant:

```bash
gh api repos/jcampbell11245/InfiniteLabyrinth/pulls/<n>/reviews --input "<temp>/review.json"
gh api repos/jcampbell11245/InfiniteLabyrinth/pulls/<n>/comments --paginate \
  --jq '.[] | "\(.path):\(.line // .original_line) review=\(.pull_request_review_id)"'
```

Comment style: start with **Should fix:** where it applies; say what's wrong, the concrete
case where it goes wrong, and a fix; one point per comment; plain sentences. Don't print
the findings again after posting: give the developer a short table of where each comment
went, with a link to the review.

## Re-reviewing after new commits

When asked to look at a PR again:

1. Pull the branch and list what's new: `git log --oneline <last reviewed sha>..HEAD`,
   `git diff <last reviewed sha>..HEAD`. Read the author's replies on the threads and the
   PR's comments (`gh api .../pulls/<n>/comments`, `gh pr view <n> --json comments`). If
   replies came through garbled, say so.
2. Check each earlier comment against the new code: **fixed**, **partly fixed** or **not
   fixed**, in a table. Don't take the author's word for it: open the code, and the
   screenshots for visual fixes.
3. Review the new code as in step 4, run the checks and screenshots again, and check
   whether the PR now conflicts with master.
4. Report what's fixed, what's new and what's left, and ask whether to post comments on the
   rest, or whether it's ready to approve.
