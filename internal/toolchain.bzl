"""
Defines the Periphery toolchain used by the scan rules to locate the
Periphery executable.
"""

def _periphery_toolchain_impl(ctx):
    if not ctx.attr.binary:
        fail(
            "No Periphery binary is configured. Configure one in your MODULE.bazel:\n\n" +
            "periphery = use_extension(\"@rules_periphery//:extensions.bzl\", \"periphery\")\n" +
            "periphery.binary_archive(url = \"...\", sha256 = \"...\")\n\n" +
            "or, for a binary on the local machine:\n\n" +
            "periphery.local_binary(path = \"path/to/periphery\")\n\n" +
            "or, to scan with a binary built from source in this workspace, register a\n" +
            "toolchain using periphery_toolchain from @rules_periphery//:toolchain.bzl.",
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
