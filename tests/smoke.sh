#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/simple_bazel"

cd "$FIXTURE"
"$REPO_ROOT/tools/periphery-bazel" --query "//:app" -- --quiet
