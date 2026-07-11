"""
Bzlmod extensions for wiring Periphery into a Bazel workspace.
"""

load("//:versions.bzl", "PERIPHERY_RELEASES")

_RELEASE_URL_TEMPLATE = "https://github.com/periphery-pro/cli-releases/releases/download/{version}/periphery-cli_{version}_{os}_{arch}.zip"

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

def _write_extracted_binary_build(repository_ctx, binary_path):
    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "periphery",
    srcs = ["bin/{binary_path}"],
    data = glob(["bin/**"]),
    visibility = ["//visibility:public"],
)
""".format(binary_path = binary_path) + _TOOLCHAIN_BUILD,
    )

def _periphery_archive_repo_impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = repository_ctx.attr.url,
        sha256 = repository_ctx.attr.sha256,
        stripPrefix = repository_ctx.attr.strip_prefix,
        output = "bin",
    )
    _write_extracted_binary_build(repository_ctx, repository_ctx.attr.binary_path)

periphery_archive_repo = repository_rule(
    implementation = _periphery_archive_repo_impl,
    attrs = {
        "binary_path": attr.string(default = "periphery"),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "url": attr.string(mandatory = True),
    },
)

def _host_platform(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    if os_name.startswith("mac") or "darwin" in os_name:
        os = "macos"
    elif "linux" in os_name:
        os = "linux"
    else:
        fail("Periphery releases do not support this operating system: " + os_name)

    arch = repository_ctx.os.arch.lower()
    if arch in ("aarch64", "arm64"):
        arch = "arm64"
    elif arch in ("x86_64", "amd64"):
        arch = "x86_64"
    else:
        fail("Periphery releases do not support this architecture: " + arch)

    return os, arch

def _periphery_release_repo_impl(repository_ctx):
    os, arch = _host_platform(repository_ctx)
    platform = "{}_{}".format(os, arch)
    version = repository_ctx.attr.version

    sha256 = repository_ctx.attr.sha256.get(platform)
    if not sha256:
        fail("No checksum for Periphery {} on {}. Pass it to periphery.release(), e.g. sha256 = {{\"{}\": \"...\"}}.".format(
            version,
            platform,
            platform,
        ))

    repository_ctx.download_and_extract(
        url = repository_ctx.attr.url_template.format(
            version = version,
            os = os,
            arch = arch,
        ),
        sha256 = sha256,
        output = "bin",
    )
    _write_extracted_binary_build(repository_ctx, "periphery")

periphery_release_repo = repository_rule(
    implementation = _periphery_release_repo_impl,
    attrs = {
        "sha256": attr.string_dict(mandatory = True),
        "url_template": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
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
exec {executable_path} "$@"
""".format(
            # Single-quoted so paths containing `$`, quotes, or backticks
            # survive intact.
            executable_path = "'" + path.replace("'", "'\\''") + "'",
        ),
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

_release = tag_class(
    attrs = {
        "sha256": attr.string_dict(
            doc = "Checksums keyed by platform (e.g. \"macos_arm64\"). Merged over the checksums shipped in versions.bzl, so only versions unknown to this ruleset need them.",
        ),
        "url_template": attr.string(
            default = _RELEASE_URL_TEMPLATE,
            doc = "Archive URL template; {version}, {os}, and {arch} are substituted.",
        ),
        "version": attr.string(mandatory = True),
    },
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
    release = None
    binary_archive = None
    local_binary = None

    for module in module_ctx.modules:
        for tag in module.tags.release:
            if release or binary_archive or local_binary:
                fail("Only one periphery binary source may be configured.")
            release = tag

        for tag in module.tags.binary_archive:
            if release or binary_archive or local_binary:
                fail("Only one periphery binary source may be configured.")
            binary_archive = tag

        for tag in module.tags.local_binary:
            if release or binary_archive or local_binary:
                fail("Only one periphery binary source may be configured.")
            local_binary = tag

    if release:
        sha256 = dict(PERIPHERY_RELEASES.get(release.version, {}))
        sha256.update(release.sha256)
        if not sha256:
            fail(
                "Unknown Periphery release '{}'. Update rules_periphery to a version that knows it, ".format(release.version) +
                "or pass checksums: periphery.release(version = ..., sha256 = {\"macos_arm64\": \"...\", ...}).",
            )
        periphery_release_repo(
            name = "periphery_bin",
            sha256 = sha256,
            url_template = release.url_template,
            version = release.version,
        )
    elif local_binary:
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
        "release": _release,
    },
)
