#!/usr/bin/env bash
# Exercise platform selection without Swift or a remote execution service.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT/tests/fixtures/platforms"

case "$(uname -s)" in
    Darwin) host_os=osx; other_os=linux ;;
    Linux) host_os=linux; other_os=osx ;;
    *) echo "Unsupported test host OS" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    arm64|aarch64) host_cpu=aarch64; other_cpu=x86_64 ;;
    x86_64) host_cpu=x86_64; other_cpu=aarch64 ;;
    *) echo "Unsupported test host CPU" >&2; exit 1 ;;
esac
host="$host_os-$host_cpu"

assert_output() {
    local output="$1" expected="$2"
    if ! grep -qxF "$expected" <<<"$output"; then
        echo "$output" >&2
        echo "Expected: $expected" >&2
        exit 1
    fi
}

for platform in other_os other_cpu other_both; do
    case "$platform" in
        other_os) remote="$other_os-$host_cpu" ;;
        other_cpu) remote="$host_os-$other_cpu" ;;
        other_both) remote="$other_os-$other_cpu" ;;
    esac
    # Also cross-compile the scanned target: changing scan's target platform
    # to the host would silently break this assertion.
    flags=("--extra_execution_platforms=//:$platform" "--platforms=//:$platform")
    echo "--- platforms: host=$host execution=$remote"
    out="$(bazel run "${flags[@]}" //:scan 2>&1)" || { echo "$out"; exit 1; }
    assert_output "$out" "scanner=$host target=$remote"

    # scan_auto's nested invocation must obey the same platform selection.
    out="$(bazel run //:auto -- --bazel-arg "${flags[0]}" --bazel-arg "${flags[1]}" 2>&1)" || { echo "$out"; exit 1; }
    assert_output "$out" "scanner=$host target=$remote"

    out="$(bazel test "${flags[@]}" --test_output=all //:scan_test 2>&1)" || { echo "$out"; exit 1; }
    assert_output "$out" "scanner=$remote target=$remote"

    bazel build "${flags[@]}" //:report
    report="$(bazel cquery "${flags[@]}" --output=files //:report 2>/dev/null)"
    assert_output "$(cat "$report")" "scanner=$remote target=$remote"

    # Portable scripts can run locally even with a foreign execution platform.
    # Inspect the action graph to prove compilation and report/test execution
    # still select the preferred worker; runtime output alone cannot prove it.
    bazel aquery "${flags[@]}" --output=jsonproto \
        'mnemonic("FixtureCompile|PeripheryScan|TestRunner", deps(set(//:scan //:report //:scan_test)))' |
        python3 -c '
import json, sys
expected = sys.argv[1]
actions = json.load(sys.stdin)["actions"]
for mnemonic in ("FixtureCompile", "PeripheryScan", "TestRunner"):
    matches = [a for a in actions if a["mnemonic"] == mnemonic]
    assert matches, f"Missing {mnemonic} action"
    for action in matches:
        assert action["executionPlatform"].endswith(expected), action
' "//:$platform"
done

echo "platforms: all tests passed"
