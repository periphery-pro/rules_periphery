#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/simple_bazel"

cd "$FIXTURE"

# Direct invocation of the driver script (local-dev workflow).
"$REPO_ROOT/tools/periphery-bazel" --query "//:app" -- --quiet

# Bazel as the entrypoint via a consumer-defined `periphery` target.
bazel run //:periphery
