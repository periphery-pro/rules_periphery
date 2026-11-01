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

echo "--- e2e: auto-discovery scan (bazel run //:scan_auto)"
out="$(bazel run //:scan_auto 2>&1)" || { echo "$out"; fail "bazel run //:scan_auto exited non-zero"; }
grep -q "UnusedSymbol" <<<"$out" || { echo "$out"; fail "expected UnusedSymbol in auto-discovery scan output"; }

echo "--- e2e: auto-discovery scan with visibility checking (bazel run //:scan_auto_checked)"
out="$(bazel run //:scan_auto_checked 2>&1)" || { echo "$out"; fail "bazel run //:scan_auto_checked exited non-zero"; }
grep -q "UnusedSymbol" <<<"$out" || { echo "$out"; fail "expected UnusedSymbol in checked-visibility scan output"; }

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

assert_embedded_findings() {
    local context="$1" out="$2"
    for symbol in unusedFrameworkFunction unusedServiceFunction; do
        grep -q "$symbol" <<<"$out" || { echo "$out"; fail "$context: expected $symbol"; }
    done
}

echo "--- e2e: app-only scan includes embedded frameworks and XPC services"
out="$(bazel run //apple:scan 2>&1)" || { echo "$out"; fail "app-only scan exited non-zero"; }
assert_embedded_findings "app-only scan" "$out"

echo "--- e2e: app-only scan_test fails with findings from both embedded targets"
if out="$(bazel test //apple:scan_test --test_output=all 2>&1)"; then
    fail "app-only scan_test should fail"
fi
assert_embedded_findings "app-only scan_test" "$out"

echo "--- e2e: app-only scan_report includes both embedded targets in its sandbox"
bazel build //apple:report || fail "building //apple:report failed"
report="$(bazel cquery --output=files //apple:report 2>/dev/null | head -1)"
[ -s "$report" ] || fail "app-only report file is missing or empty"
python3 - "$report" <<'PY'
import json
import sys

with open(sys.argv[1]) as report:
    names = sorted(finding["name"] for finding in json.load(report))
expected = ["unusedFrameworkFunction()", "unusedServiceFunction()"]
if names != expected:
    raise SystemExit(f"Expected only embedded-target findings {expected}, got {names}")
PY

echo "e2e: all tests passed"
