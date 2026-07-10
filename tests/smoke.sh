#!/usr/bin/env bash
# Plumbing tests for the `local_binary` binary source. The configured "binary"
# is /bin/echo, so the scan command line is echoed rather than executed. This
# needs no Swift toolchain; see e2e.sh for tests that really scan.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/simple_bazel"

cd "$FIXTURE"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

# The stub binary prints one argument per line, so these assertions check
# exact argv entries, not substrings.
assert_scan_command() {
    local context="$1" out="$2"

    grep -qx "scan" <<<"$out" || { echo "$out"; fail "$context: expected a 'scan' command"; }
    grep -qx -- "--generic-project-config" <<<"$out" || { echo "$out"; fail "$context: missing --generic-project-config"; }
    grep -qx -- "--quiet" <<<"$out" || { echo "$out"; fail "$context: periphery_args not forwarded"; }

    # No config was configured, so the flag must be omitted entirely rather
    # than passed with an empty value.
    if grep -q -- "--config" <<<"$out"; then
        echo "$out"
        fail "$context: --config passed without a config"
    fi
}

# Arguments containing spaces or make-variable-like tokens must arrive as
# single argv entries, exactly as written in the BUILD file.
assert_arg_boundaries() {
    local context="$1" out="$2"

    grep -qxF -- '**/A B $(C)/**' <<<"$out" || { echo "$out"; fail "$context: spaced argument was split or altered"; }
}

echo "--- smoke: direct invocation of the driver script (local-dev workflow)"
out="$("$REPO_ROOT/tools/periphery-bazel" --query "//:app" -- --quiet 2>&1)" || { echo "$out"; fail "direct invocation exited non-zero"; }
assert_scan_command "direct invocation" "$out"

echo "--- smoke: a periphery binary built from source, via periphery_toolchain"
out="$(cd "$REPO_ROOT/tests/fixtures/local_target" && bazel run //:periphery 2>&1)" || { echo "$out"; fail "local_target fixture exited non-zero"; }
assert_scan_command "local_target" "$out"

echo "--- smoke: Bazel as the entrypoint via a consumer-defined periphery target"
out="$(bazel run //:periphery 2>&1)" || { echo "$out"; fail "bazel run //:periphery exited non-zero"; }
assert_scan_command "bazel run" "$out"
assert_arg_boundaries "bazel run" "$out"

echo "smoke: all tests passed"
