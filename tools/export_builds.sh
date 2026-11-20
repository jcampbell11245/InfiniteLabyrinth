#!/usr/bin/env bash
# Exports every preset in export_presets.cfg and zips each one's output folder on its own,
# ready to attach to a GitHub release (see the make-release skill).
#
#   tools/export_builds.sh
#
# Each preset writes into its own folder under builds/ (its export_path). That folder is
# emptied first, so files left over from an older export can't end up in the zip. Then
# builds/<folder> is zipped, flat, into builds/InfiniteLabyrinth-<folder>.zip.
#
# Builds are debug exports, like every release so far, so the F2 debug menu works in them.
# Needs Godot 4.7.2 in GODOT (or `godot` on the PATH) and its export templates installed.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "Godot not found. Set GODOT to the Godot 4.7.2 executable (see README: Setup)." >&2
	exit 2
fi

# "name|export_path" for each [preset.N] section, skipping the [preset.N.options] ones.
presets=$(awk '
	/^\[preset\.[0-9]+\]$/ { in_preset = 1; next }
	/^\[/ { in_preset = 0 }
	in_preset && /^name=/ { name = substr($0, 7, length($0) - 7) }
	in_preset && /^export_path=/ { print name "|" substr($0, 14, length($0) - 14) }
' export_presets.cfg)

if [ -z "$presets" ]; then
	echo "No presets found in export_presets.cfg." >&2
	exit 1
fi

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

folders=()
while IFS='|' read -r name path; do
	dir=$(dirname "$path")
	case "$dir" in
		builds/?*) ;;
		*) echo "Preset \"$name\" exports to $path, outside builds/: refusing to empty it." >&2; exit 1 ;;
	esac
	printf '\n== Exporting %s -> %s\n' "$name" "$path"
	rm -rf "$dir"
	mkdir -p "$dir"
	"$GODOT" --headless --path . --export-debug "$name" "$path"
	if [ -z "$(ls -A "$dir")" ]; then
		echo "Export of \"$name\" wrote nothing to $dir." >&2
		exit 1
	fi
	folders+=("$dir")
done <<< "$presets"

printf '\n== Zipping\n'
"$GODOT" --headless --path . -s res://tools/zip_builds.gd -- "${folders[@]}"

printf '\nBuilds ready:\n'
for dir in "${folders[@]}"; do
	ls -l "builds/InfiniteLabyrinth-$(basename "$dir").zip"
done
