# Periphery Bazel Driver

Open-source Bazel integration for Periphery.

## Module Setup

For released Periphery archives:

```starlark
bazel_dep(name = "periphery_bazel_driver", version = "0.0.0")

periphery = use_extension("@periphery_bazel_driver//:extensions.bzl", "periphery")
periphery.binary_archive(
    url = "https://example.com/periphery.zip",
    sha256 = "...",
    binary_path = "periphery",
)
use_repo(periphery, "periphery_bin", "periphery_generated")
```

For local development with an existing Periphery binary:

```starlark
bazel_dep(name = "periphery_bazel_driver", version = "0.0.0")
local_path_override(
    module_name = "periphery_bazel_driver",
    path = "../bazel-driver",
)

periphery = use_extension("@periphery_bazel_driver//:extensions.bzl", "periphery")
periphery.local_binary(
    path = "/absolute/path/to/periphery",
)
use_repo(periphery, "periphery_bin", "periphery_generated")
```

## Running

Run the driver from your Bazel workspace:

```sh
periphery-bazel -- --config .periphery.yml
```

Useful driver options:

- `--query <expr>` overrides the default top-level target query.
- `--filter <pattern>` filters the default top-level target query.
- `--global-indexstore <path>` uses a global index store instead of module index stores.
- `--check-visibility` runs Bazel with visibility checking enabled.
- `--bazel-arg <arg>` forwards an argument to `bazel run`.

Arguments not recognized by the driver are forwarded to `periphery scan`.
