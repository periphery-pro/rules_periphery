# Periphery Bazel Rules

Bazel integration for [Periphery](https://periphery.pro).

## Module Setup

Add `rules_periphery` to your `MODULE.bazel` and configure the Periphery
binary to scan with. For a Periphery release, name its version; the archive
for the host platform is downloaded and verified against checksums shipped
with this ruleset:

```starlark
PERIPHERY_VERSION = "1.0.0"

bazel_dep(name = "rules_periphery", version = PERIPHERY_VERSION)

periphery = use_extension("@rules_periphery//:extensions.bzl", "periphery")
periphery.release(version = "1.0.0")
use_repo(periphery, "periphery_generated")
```

Versions this ruleset doesn't know yet can be used by supplying their
checksums (found alongside each release):

```starlark
periphery.release(
    version = "1.1.0",
    sha256 = {
        "linux_arm64": "...",
        "linux_x86_64": "...",
        "macos_arm64": "...",
        "macos_x86_64": "...",
    },
)
```

To use an archive that isn't an official release:

```starlark
periphery.binary_archive(
    # This example uses the macOS Apple Silicon archive.
    url = "https://github.com/periphery-pro/cli-releases/releases/download/{0}/periphery-cli_{0}_macos_arm64.zip".format(PERIPHERY_VERSION),
    sha256 = "...",
)
```

Or, to use a Periphery binary from your local machine:

```starlark
periphery = use_extension("@rules_periphery//:extensions.bzl", "periphery")
periphery.local_binary(
    # Absolute, or relative to the workspace root.
    path = "path/to/periphery",
)
```

`local_binary` refers to a path on disk, which Bazel neither builds nor tracks.

The configured binary is exposed to the scan rules as a toolchain; you don't
need to reference it directly. `use_repo(periphery, "periphery_generated")` is
only required when using the [scan target generation](#generating-the-scan-target)
entry point.

## Declaring scan targets

Three rules are provided:

- `scan` — an executable target that prints results when run with `bazel run`.
- `scan_test` — a test target that fails when unused code is found. Use this
  to run Periphery in CI via `bazel test`.
- `scan_report` — a build target that runs Periphery at build time and writes
  the formatted report to a file output, which other rules can consume via
  `data` deps or `srcs`.

Apply them to your top-level targets (applications, tests, command-line
tools, etc.); their transitive dependencies are scanned too:

```starlark
load("@rules_periphery//:rules.bzl", "scan", "scan_report", "scan_test")

scan(
    name = "scan",
    config = ".periphery.yml",
    deps = [
        "//App:MyApp",
        "//Tests:MyAppTests",
    ],
)

scan_test(
    name = "scan_test",
    config = ".periphery.yml",
    deps = [
        "//App:MyApp",
        "//Tests:MyAppTests",
    ],
)

scan_report(
    name = "scan_report",
    config = ".periphery.yml",
    format = "json",
    deps = [
        "//App:MyApp",
        "//Tests:MyAppTests",
    ],
)
```

```sh
# Print results.
bazel run //:scan

# Fail if unused code is found.
bazel test //:scan_test

# Write a report file to bazel-bin/scan_report.report.
bazel build //:scan_report
```

All rules accept `periphery_args` for forwarding additional arguments to
`periphery scan`. Files referenced by those arguments — such as a baseline —
must be declared via the `data` attribute:

```starlark
scan_test(
    name = "scan_test",
    config = ".periphery.yml",
    data = ["baseline.json"],
    periphery_args = [
        "--baseline",
        "baseline.json",
    ],
    deps = ["//App:MyApp"],
)
```

`scan_report`'s `format` accepts any of Periphery's output formats: `xcode`,
`csv`, `json`, `checkstyle`, `codeclimate`, `github-actions`,
`github-markdown`, `gitlab-codequality`.

## Generating the scan target

If you'd rather not maintain the `deps` list by hand, the `scan_auto` macro
discovers your workspace's top-level targets automatically:

```starlark
load("@rules_periphery//:defs.bzl", "scan_auto")

scan_auto(
    name = "scan_auto",
)
```

```sh
bazel run //:scan_auto
```

Running the target queries your workspace for top-level targets, generates a
hidden `scan` target, and runs it through a nested `bazel run
@periphery_generated//:scan`.

The macro accepts optional configuration:

```starlark
scan_auto(
    name = "scan_auto",
    # Override the default top-level target query.
    query = "filter('^//App', kind('(ios_application) rule', deps(//...)))",
    # Or just filter the default query.
    filter = "^//App",
    # Use a global index store instead of per-module stores.
    global_indexstore = "/path/to/indexstore",
    # Run the scan with Bazel visibility checking enabled.
    check_visibility = True,
    # Extra arguments forwarded to the nested `bazel run`.
    bazel_args = [],
    # Arguments forwarded to `periphery scan`.
    periphery_args = ["--config", ".periphery.yml"],
)
```

Additional arguments can also be forwarded to `periphery scan` at runtime:

```sh
bazel run //:scan_auto -- --strict --quiet
```

### Visibility checking

By default the generated scan target is built with `--check_visibility=false`,
since it references targets across your workspace that may not be visible to
it. Disabling visibility checking can invalidate Bazel's analysis cache,
resulting in slower subsequent builds.

Set `check_visibility = True` to avoid that, and grant the generated scan
target visibility to the targets it scans using the `@rules_periphery//:generated`
package group:

```starlark
swift_library(
    name = "MyLib",
    visibility = ["@rules_periphery//:generated"],
)
```

## Development

```sh
# Plumbing tests using a stub binary.
./tests/smoke.sh

# End-to-end tests using a real Periphery release binary (requires macOS).
./tests/e2e.sh

# Lint.
mise run lint
```
