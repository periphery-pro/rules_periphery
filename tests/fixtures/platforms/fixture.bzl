"""Portable stand-ins for a compiled scanner and an indexed Swift target."""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_swift//swift:providers.bzl", "SwiftInfo")

_OS = ["linux", "osx"]
_CPUS = ["aarch64", "x86_64"]

def platforms(name):
    """Declares platforms differing from the host in OS, CPU, or both.

    Args:
        name: Prefix for the platform targets.
    """
    host_os = [c for c in HOST_CONSTRAINTS if "//os:" in c][0]
    host_cpu = [c for c in HOST_CONSTRAINTS if "//cpu:" in c][0]
    other_os = "@platforms//os:" + ("linux" if host_os.endswith(":osx") else "osx")
    other_cpu = "@platforms//cpu:" + ("x86_64" if host_cpu.endswith(":aarch64") else "aarch64")
    for suffix, constraints in {
        "os": [other_os, host_cpu],
        "cpu": [host_os, other_cpu],
        "both": [other_os, other_cpu],
    }.items():
        native.platform(name = name + "_" + suffix, constraint_values = constraints)

def _platform(ctx):
    return "-".join([
        name
        for name in _OS + _CPUS
        if ctx.target_platform_has_constraint(getattr(ctx.attr, "_" + name)[platform_common.ConstraintValueInfo])
    ])

_PLATFORM_ATTRS = {
    "_" + name: attr.label(default = "@platforms//" + kind + ":" + name)
    for kind, names in {"os": _OS, "cpu": _CPUS}.items()
    for name in names
}

def _scanner_impl(ctx):
    binary = ctx.actions.declare_file(ctx.label.name + ".sh")
    data = ctx.actions.declare_file("scanner.data")
    ctx.actions.write(data, "scanner runfiles\n")
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = binary,
        substitutions = {"%platform%": _platform(ctx)},
        is_executable = True,
    )
    return [DefaultInfo(executable = binary, runfiles = ctx.runfiles(files = [data]))]

scanner = rule(
    implementation = _scanner_impl,
    executable = True,
    attrs = _PLATFORM_ATTRS | {
        "_template": attr.label(default = "scanner.sh", allow_single_file = True),
    },
)

def _compile_toolchain_impl(_ctx):
    return [platform_common.ToolchainInfo()]

compile_toolchain = rule(implementation = _compile_toolchain_impl)

def _indexed_target_impl(ctx):
    if "swift.index_while_building" not in ctx.features:
        fail("scan deps must still enable index generation")
    indexstore = ctx.actions.declare_directory(ctx.label.name + ".indexstore")
    ctx.actions.run_shell(
        outputs = [indexstore],
        command = "mkdir -p {path}; echo {platform} > {path}/platform".format(
            path = indexstore.path,
            platform = _platform(ctx),
        ),
        mnemonic = "FixtureCompile",
        toolchain = "//:compile_toolchain_type",
    )
    return [
        DefaultInfo(files = depset([indexstore])),
        SwiftInfo(modules = [struct(
            name = "App",
            compilation_context = struct(direct_sources = ()),
            swift = struct(indexstore = indexstore),
        )]),
    ]

indexed_target = rule(
    implementation = _indexed_target_impl,
    attrs = _PLATFORM_ATTRS,
    toolchains = ["//:compile_toolchain_type"],
)
