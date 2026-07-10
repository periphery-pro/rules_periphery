# Periphery Bazel Driver

Open-source Bazel integration for Periphery.

## Module Setup

For released Periphery archives:

```starlark
bazel_dep(name = "rules_periphery", version = "0.0.0")

periphery = use_extension("@rules_periphery//:extensions.bzl", "periphery")
periphery.binary_archive(
    url = "https://example.com/periphery.zip",
    sha256 = "...",
    binary_path = "periphery",
)
use_repo(periphery, "periphery_bin", "periphery_generated")
```

If you prefer to refer to the module as `@periphery`, alias it on your side with
`repo_name` (works for any workspace that isn't itself the `periphery` module):

```starlark
bazel_dep(name = "rules_periphery", version = "0.0.0", repo_name = "periphery")

periphery = use_extension("@periphery//:extensions.bzl", "periphery")
```

For local development with an existing Periphery binary:

```starlark
bazel_dep(name = "rules_periphery", version = "0.0.0")
local_path_override(
    module_name = "rules_periphery",
    path = "../bazel-driver",
)

periphery = use_extension("@rules_periphery//:extensions.bzl", "periphery")
periphery.local_binary(
    path = "/absolute/path/to/periphery",
)
use_repo(periphery, "periphery_bin", "periphery_generated")
```

## Defining the scan target

Define a target in your own `BUILD.bazel` using the `periphery` macro. You can
name it whatever you like:

```starlark
load("@rules_periphery//:defs.bzl", "periphery")

periphery(
    name = "periphery",
)
```

Then Bazel is the entrypoint:

```sh
bazel run //:periphery
```

Running the target discovers your top-level targets, generates a hidden `scan`
target, and invokes `periphery scan --generic-project-config` through a nested
`bazel run @periphery_generated//:scan`.

The macro accepts optional configuration:

```starlark
periphery(
    name = "periphery",
    # Override the default top-level target query.
    query = "filter('^//App', kind('(ios_application) rule', deps(//...)))",
    # Or just filter the default query.
    filter = "^//App",
    # Use a global index store instead of per-module stores.
    global_indexstore = "/path/to/indexstore",
    # Run the scan with Bazel visibility checking enabled.
    check_visibility = False,
    # Extra arguments forwarded to the nested `bazel run`.
    bazel_args = [],
    # Arguments forwarded to `periphery scan`.
    periphery_args = ["--config", ".periphery.yml"],
)
```

Additional arguments can also be forwarded to `periphery scan` at runtime:

```sh
bazel run //:periphery -- --strict --quiet
```

The underlying `tools/periphery-bazel` script can also be run directly (outside
`bazel run`) from a workspace directory, which is useful for local development.
