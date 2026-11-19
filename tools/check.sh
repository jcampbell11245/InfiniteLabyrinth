#!/usr/bin/env bash
# Runs the same checks a pull request must pass on GitHub (.github/workflows/checks.yml):
# import the project, the headless smoke test, then the automated tests.
#
#   tools/check.sh                # everything
#   tools/check.sh tests time     # only the tests whose file name contains "time"
#
# Needs Godot 4.7.2: set GODOT to its executable (the console one on Windows), or put
# `godot` on the PATH. Works in Git Bash on Windows.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot not found. Set GODOT to the Godot 4.7.2 executable (see README: Setup)." >&2
	exit 2
fi

step() { printf '\n== %s\n' "$1"; }

if [ "${1:-}" != "tests" ]; then
	step "Import"
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
	step "Smoke test"
	"$GODOT" --headless --path . -s res://tools/smoke_test.gd
fi

step "Tests"
if [ "${1:-}" = "tests" ] && [ -n "${2:-}" ]; then
	"$GODOT" --headless --path . -s res://tools/run_tests.gd -- "$2"
else
	"$GODOT" --headless --path . -s res://tools/run_tests.gd
fi

printf '\nAll checks passed.\n'
