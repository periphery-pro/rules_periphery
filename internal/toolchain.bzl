"""
Defines the Periphery toolchain used by the scan rules to locate the
Periphery executable.
"""

def _periphery_toolchain_impl(ctx):
    if not ctx.attr.binary:
        fail(
            "No Periphery binary is configured. Configure one in your MODULE.bazel:\n\n" +
            "periphery = use_extension(\"@rules_periphery//:extensions.bzl\", \"periphery\")\n" +
            "periphery.binary_archive(url = \"...\", sha256 = \"...\")",
        )

    info = ctx.attr.binary[DefaultInfo]
    return [
        platform_common.ToolchainInfo(
            periphery_files_to_run = info.files_to_run,
            periphery_runfiles = info.default_runfiles,
        ),
    ]

periphery_toolchain = rule(
    doc = "Declares a Periphery executable as a toolchain implementation.",
    implementation = _periphery_toolchain_impl,
    attrs = {
        "binary": attr.label(
            doc = "The Periphery executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)
