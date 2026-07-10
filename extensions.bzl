"""
Bzlmod extensions for wiring Periphery into a Bazel workspace.
"""

_TOOLCHAIN_BUILD = """
load("@rules_periphery//internal:toolchain.bzl", "periphery_toolchain")

periphery_toolchain(
    name = "periphery_toolchain",
    binary = ":periphery",
)

toolchain(
    name = "toolchain",
    toolchain = ":periphery_toolchain",
    toolchain_type = "@rules_periphery//:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

_STUB_TOOLCHAIN_BUILD = """
load("@rules_periphery//internal:toolchain.bzl", "periphery_toolchain")

periphery_toolchain(
    name = "periphery_toolchain",
)

toolchain(
    name = "toolchain",
    toolchain = ":periphery_toolchain",
    toolchain_type = "@rules_periphery//:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

def _periphery_archive_repo_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.url,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = repository_ctx.attr.strip_prefix,
        output = "bin",
    )
    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "periphery",
    srcs = ["bin/{binary_path}"],
    data = glob(["bin/**"]),
    visibility = ["//visibility:public"],
)
""".format(binary_path = repository_ctx.attr.binary_path) + _TOOLCHAIN_BUILD,
    )

periphery_archive_repo = repository_rule(
    implementation = _periphery_archive_repo_impl,
    attrs = {
        "binary_path": attr.string(default = "periphery"),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "url": attr.string(mandatory = True),
    },
)

def _periphery_local_repo_impl(repository_ctx):
    path = repository_ctx.attr.path
    if not path.startswith("/"):
        path = "{}/{}".format(repository_ctx.workspace_root, path)

    repository_ctx.file(
        "periphery.sh",
        """#!/usr/bin/env bash
set -euo pipefail
exec "{executable_path}" "$@"
""".format(executable_path = path),
        executable = True,
    )
    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "periphery",
    srcs = ["periphery.sh"],
    visibility = ["//visibility:public"],
)
""" + _TOOLCHAIN_BUILD,
    )

periphery_local_repo = repository_rule(
    implementation = _periphery_local_repo_impl,
    attrs = {
        "path": attr.string(mandatory = True),
    },
    local = True,
)

def _periphery_stub_repo_impl(repository_ctx):
    repository_ctx.file("BUILD.bazel", _STUB_TOOLCHAIN_BUILD)

periphery_stub_repo = repository_rule(
    implementation = _periphery_stub_repo_impl,
)

def _workspace_output_dir(repository_ctx):
    return "/var/tmp/periphery_bazel/{}".format(
        str(repository_ctx.workspace_root).replace("/", "_"),
    )

def _generated_repo_impl(repository_ctx):
    repository_ctx.file(
        "visibility/BUILD.bazel",
        """package_group(
    name = "package_group",
    packages = ["//..."],
)
""",
    )
    repository_ctx.symlink(
        "{}/BUILD.bazel".format(_workspace_output_dir(repository_ctx)),
        "BUILD.bazel",
    )

periphery_generated_repo = repository_rule(
    implementation = _generated_repo_impl,
    local = True,
)

_binary_archive = tag_class(
    attrs = {
        "binary_path": attr.string(default = "periphery"),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "url": attr.string(mandatory = True),
    },
)

_local_binary = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

def _periphery_extension_impl(module_ctx):
    binary_archive = None
    local_binary = None

    for module in module_ctx.modules:
        for tag in module.tags.binary_archive:
            if binary_archive or local_binary:
                fail("Only one periphery binary source may be configured.")
            binary_archive = tag

        for tag in module.tags.local_binary:
            if binary_archive or local_binary:
                fail("Only one periphery binary source may be configured.")
            local_binary = tag

    if local_binary:
        periphery_local_repo(
            name = "periphery_bin",
            path = local_binary.path,
        )
    elif binary_archive:
        periphery_archive_repo(
            name = "periphery_bin",
            binary_path = binary_archive.binary_path,
            sha256 = binary_archive.sha256,
            strip_prefix = binary_archive.strip_prefix,
            url = binary_archive.url,
        )
    else:
        periphery_stub_repo(name = "periphery_bin")

    periphery_generated_repo(name = "periphery_generated")

periphery = module_extension(
    implementation = _periphery_extension_impl,
    tag_classes = {
        "binary_archive": _binary_archive,
        "local_binary": _local_binary,
    },
)
