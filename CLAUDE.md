@AGENTS.md

When a developer asks you to change anything in this repository (a feature, fix, tweak,
asset or doc change), invoke the `make-change` skill first: it claims the work in a GitHub
issue and sets up the branch before you edit, then takes the change through the checks to
a pushed branch, opening the pull request only when the developer says it's ready.

When a developer asks for a new release (a new version, builds published to GitHub), invoke
the `make-release` skill instead: it exports and zips every build, drafts the release notes
and creates the GitHub release.

When a developer asks you to review a pull request (or to look at one again after new
commits), invoke the `review-pr` skill: it checks out the branch, reviews and tests it, and
reports back before posting any comments.
