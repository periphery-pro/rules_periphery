"""
Public Periphery toolchain rule.

Most workspaces do not need this: configure a binary with the `periphery`
module extension and its toolchain is registered for you.

Use this only to scan with a Periphery binary built from source in your own
workspace, so that Bazel builds and tracks it like any other target:

```starlark
load("@rules_periphery//:toolchain.bzl", "periphery_toolchain")

periphery_toolchain(
    name = "periphery_binary",
    binary = "//path/to:periphery",
)

toolchain(
    name = "periphery_toolchain",
    toolchain = ":periphery_binary",
    toolchain_type = "@rules_periphery//:toolchain_type",
)
```

Then register it in your `MODULE.bazel`, where it takes precedence over the
toolchain the module extension registers:

```starlark
register_toolchains("//:periphery_toolchain")
```
"""

load("//internal:toolchain.bzl", _periphery_toolchain = "periphery_toolchain")

periphery_toolchain = _periphery_toolchain
