"""
Bzlmod extensions for wiring Periphery into a Bazel workspace.
"""

def _write_periphery_build(repository_ctx, executable_path):
    repository_ctx.file(
        "periphery_binary.bzl",
        """def _periphery_binary_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = executable, target_file = ctx.file.src, is_executable = True)
    return DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = ctx.files.data),
    )

periphery_binary = rule(
    implementation = _periphery_binary_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "src": attr.label(allow_single_file = True, executable = True, cfg = "target", mandatory = True),
    },
    executable = True,
)
""",
    )
    repository_ctx.file(
        "periphery.sh",
        """#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/{executable_path}" "$@"
""".format(executable_path = executable_path),
        executable = True,
    )
    repository_ctx.file(
        "BUILD.bazel",
        """load(":periphery_binary.bzl", "periphery_binary")

periphery_binary(
    name = "periphery",
    src = "periphery.sh",
    data = ["{executable_path}"],
    visibility = ["//visibility:public"],
)
""".format(executable_path = executable_path),
    )

def _write_local_periphery_build(repository_ctx, executable_path):
    repository_ctx.file(
        "periphery_binary.bzl",
        """def _periphery_binary_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = executable, target_file = ctx.file.src, is_executable = True)
    return DefaultInfo(executable = executable)

periphery_binary = rule(
    implementation = _periphery_binary_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, executable = True, cfg = "target", mandatory = True),
    },
    executable = True,
)
""",
    )
    repository_ctx.file(
        "periphery.sh",
        """#!/usr/bin/env bash
set -euo pipefail
exec "{executable_path}" "$@"
""".format(executable_path = executable_path),
        executable = True,
    )
    repository_ctx.file(
        "BUILD.bazel",
        """load(":periphery_binary.bzl", "periphery_binary")

periphery_binary(
    name = "periphery",
    src = "periphery.sh",
    visibility = ["//visibility:public"],
)
""",
    )

def _periphery_archive_repo_impl(repository_ctx):
    if repository_ctx.attr.strip_prefix:
        repository_ctx.download_and_extract(
            url = repository_ctx.attr.url,
            sha256 = repository_ctx.attr.sha256,
            stripPrefix = repository_ctx.attr.strip_prefix,
        )
    else:
        repository_ctx.download_and_extract(
            url = repository_ctx.attr.url,
            sha256 = repository_ctx.attr.sha256,
        )
    _write_periphery_build(repository_ctx, repository_ctx.attr.binary_path)

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
    _write_local_periphery_build(repository_ctx, repository_ctx.attr.path)

periphery_local_repo = repository_rule(
    implementation = _periphery_local_repo_impl,
    attrs = {
        "path": attr.string(mandatory = True),
    },
    local = True,
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
        "/var/tmp/periphery_bazel/BUILD.bazel",
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
        fail("Configure either periphery.local_binary(...) or periphery.binary_archive(...).")

    periphery_generated_repo(name = "periphery_generated")

periphery = module_extension(
    implementation = _periphery_extension_impl,
    tag_classes = {
        "binary_archive": _binary_archive,
        "local_binary": _local_binary,
    },
)
