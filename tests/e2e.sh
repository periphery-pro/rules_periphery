#!/usr/bin/env bash
# End-to-end tests using a real Periphery release binary fetched via
# periphery.binary_archive(...). Requires macOS with Xcode.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/swift_app"

cd "$FIXTURE"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

echo "--- e2e: auto-discovery scan (bazel run //:periphery)"
out="$(bazel run //:periphery 2>&1)" || { echo "$out"; fail "bazel run //:periphery exited non-zero"; }
grep -q "UnusedSymbol" <<<"$out" || { echo "$out"; fail "expected UnusedSymbol in auto-discovery scan output"; }

echo "--- e2e: explicit scan target (bazel run //:app_scan)"
out="$(bazel run //:app_scan 2>&1)" || { echo "$out"; fail "bazel run //:app_scan exited non-zero"; }
grep -q "UnusedSymbol" <<<"$out" || { echo "$out"; fail "expected UnusedSymbol in scan output"; }

echo "--- e2e: scan_test passes on a clean target"
bazel test //:clean_scan_test || fail "clean_scan_test should pass"

echo "--- e2e: scan_test fails on a target with unused code"
if bazel test //:app_scan_test; then
    fail "app_scan_test should fail"
fi

echo "--- e2e: scan_test honors the config attribute"
bazel test //:app_config_scan_test || fail "app_config_scan_test should pass; the config excludes the finding"

echo "--- e2e: scan_report produces a report containing the finding"
bazel build //:app_report || fail "building //:app_report failed"
report="$(bazel cquery --output=files //:app_report 2>/dev/null | head -1)"
[ -s "$report" ] || fail "report file is missing or empty"
grep -q "UnusedSymbol" "$report" || { cat "$report"; fail "expected UnusedSymbol in report"; }

echo "e2e: all tests passed"
