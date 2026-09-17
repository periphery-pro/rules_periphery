#!/usr/bin/env bash
# This script is deliberately portable so execution-platform tests need no
# remote worker. The stamped platform records how the binary was configured.
set -euo pipefail

data="$(dirname "$0")/scanner.data"
if [ ! -f "$data" ]; then
    data="$0.runfiles/_main/scanner.data"
fi
[ "$(cat "$data")" = "scanner runfiles" ]
# Like Periphery, resolve bazel-run project paths from the workspace root.
if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
    cd "$BUILD_WORKSPACE_DIRECTORY"
fi
report=""
config=""
while [ $# -gt 0 ]; do
    case "$1" in
        --write-results) report="$2"; shift 2 ;;
        --generic-project-config) config="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Verify the indexed target was actually built and staged, not just analyzed.
indexstore="$(sed -n 's/.*"\([^"]*app.indexstore\)".*/\1/p' "$config")"
[ -n "$indexstore" ]
result="scanner=%platform% target=$(cat "$indexstore/platform")"
if [ -n "$report" ]; then
    printf '%s\n' "$result" > "$report"
else
    printf '%s\n' "$result"
fi
