---
name: make-change
description: Use whenever a developer wants to change anything in the Infinite Labyrinth repository (feature, fix, balance tweak, asset, room, docs). Claims the work in a GitHub issue (refusing if someone else is already assigned), creates the feature branch, makes the change following AGENTS.md, runs the checks CI requires, and opens a pull request that closes the issue.
---

# Make a change to Infinite Labyrinth

Every change except the project owner's goes through a feature branch and a GitHub issue
assigned to the developer making it, so no two people do the same work. `master` is
protected: a pull request merges only when **Smoke test**, **Tests** and **Linked issue**
pass, the branch is up to date with `master`, and another developer has approved it. Follow these steps in order. Don't edit files before step 4.

Repository: `jcampbell11245/InfiniteLabyrinth`. Owner: `jcampbell11245`.

## 1. Check the tools and who the developer is

```bash
git --version && gh --version && "$GODOT" --version
gh auth status
gh api user --jq .login
```

If any of these fail, help the developer finish [README.md → Setup](../../../README.md#setup)
first (Godot 4.7.2 in `GODOT`, `gh auth login`). The login printed last is the developer's
GitHub name; use it below.

If the developer is the owner (`jcampbell11245`), the issue and branch are optional: ask
whether they want them, and if not, skip to step 4 and work on `master`.

## 2. Get the branch name and the work

The developer must give you both:

- **Branch name**: short, lowercase, hyphenated, saying what it's for, e.g.
  `wizard-teleport`, `fix-pitfall-respawn`. No spaces, not `master`.
- **What they're doing**: a sentence or two you can put in an issue.

If either is missing, ask for it and wait. Don't invent them.

Check the branch name is free:

```bash
git fetch origin
git ls-remote --heads origin <branch>
```

If it prints anything, the name is taken: ask for another (or, if it's the developer's
own branch from earlier, confirm they want to continue it).

## 3. Claim the work in an issue

Search the open issues for this work, using two or three keywords from the description:

```bash
gh issue list --state open --limit 100 --json number,title,assignees,url \
  --search "<keywords>"
```

Also skim titles without a search (`gh issue list --state open --limit 100`) if the
keywords might miss it. Decide whether any open issue covers the same work. If you're not
sure, show the developer the candidates and ask.

**An issue covers it:** check who's assigned, right before acting:

```bash
gh issue view <n> --json number,title,assignees --jq '{number, title, assignees: [.assignees[].login]}'
```

- **Assigned to someone else** (anyone who isn't the developer): **stop.** Tell the
  developer the issue number, title and who has it, and don't create a branch or edit
  anything. They can talk to that person, or pick other work.
- **Assigned to the developer already**: carry on with that issue.
- **Unassigned**: assign the developer, then check again, in case someone claimed it at
  the same moment:

  ```bash
  gh issue edit <n> --add-assignee @me
  gh issue view <n> --json assignees --jq '[.assignees[].login]'
  ```

  If anyone besides the developer now shows up, remove the developer
  (`gh issue edit <n> --remove-assignee @me`), stop and tell them, as above.

**No issue covers it:** create one, assigned to the developer:

```bash
gh issue create --assignee @me --title "<short title>" --body "<what they're doing and why>

Branch: \`<branch>\`"
```

Note the issue number; the pull request must close it.

## 4. Branch from an up-to-date master

```bash
git status --short          # must be clean; if not, ask what to do with the changes
git fetch origin
git switch -c <branch> origin/master
```

(Continuing the developer's existing branch: `git switch <branch> && git pull`.)

## 5. Make the change

Follow [AGENTS.md](../../../AGENTS.md): gameplay numbers in `Tuning.gd` with a `FIELDS` row,
static typing, comments that explain why, LF line endings, careful `.tscn` edits, sound
provenance in `assets/sfx/SOURCE.txt`, README/BUGS.md updates. Add or update a test in
`tools/tests/` for rules that can be checked without the screen.

## 6. Run the checks

```bash
tools/check.sh
```

All of it must pass: it's what the pull request's **Smoke test** and **Tests** checks run.
For visual changes, take screenshots in a real window and look at them:

```bash
"$GODOT" --path . -s res://tools/screenshot.gd -- /tmp/<name> [hurt|upgrades]
```

You can't hear sounds or feel timing: list those for the developer to playtest.

## 7. Commit, push and open the pull request

```bash
git add -A && git status --short        # check nothing unintended is staged (builds/, screenshots)
git commit -m "<short plain-English subject>" -m "<what changed and why>"
git push -u origin <branch>
gh pr create --base master --head <branch> --title "<title>" --body "<summary>

How it was checked:
- tools/check.sh passes
- <screenshots looked at / tests added>

Needs a human: <playtest, listen to the new sound, ...>

Closes #<n>"
```

The description **must** contain `Closes #<n>` for the issue from step 3, or the
**Linked issue** check fails. Then watch the checks:

```bash
gh pr checks --watch
```

If one fails, read its log (`gh run view --log-failed`), fix the cause on the branch,
run `tools/check.sh` again and push. If GitHub says the branch is out of date, bring
`master` in (`git fetch origin && git merge origin/master`), re-run the checks and push.
Ask a teammate to review; it needs one approval. Don't merge the pull request yourself unless the
developer asks; when it merges, GitHub closes the issue.

## Stopping partway

If the developer drops the work, unassign them and leave a note so someone else can pick
it up: `gh issue edit <n> --remove-assignee @me` and
`gh issue comment <n> --body "Stopping work on this; branch <branch> has what was done."`
