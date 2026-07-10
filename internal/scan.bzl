"""
Declares the implementations backing the public `scan`, `scan_test`, and
`scan_report` rules.
"""

load("@bazel_skylib//lib:sets.bzl", "sets")
load("@rules_apple//apple:providers.bzl", "AppleResourceInfo")
load("@rules_swift//swift:providers.bzl", "SwiftBinaryInfo", "SwiftInfo")

visibility("//...")

TOOLCHAIN_TYPE = "//:toolchain_type"

PeripheryInfo = provider(
    doc = "Provides inputs needed to generate a generic project configuration file.",
    fields = {
        "swift_srcs": "A depset of Swift source files.",
        "indexstores": "A depset of .indexstore files.",
        "plists": "A depset of .plist files.",
        "xibs": "A depset of .xib and .storyboard files.",
        "xcdatamodels": "A depset of .xcdatamodel files.",
        "xcmappingmodels": "A depset of .xcmappingmodel files",
        "test_targets": "A depset of test only target names.",
    },
)

_TRANSITIVE_ATTRS = [
    "app_clips",
    "deps",
    "extension",
    "extensions",
    "plugins",
    "swift_target",
    "watch_application",
]

def _periphery_info_providers(rule_attr):
    providers = []
    for attr in _TRANSITIVE_ATTRS:
        value = getattr(rule_attr, attr, None)
        values = value if type(value) == "list" else ([value] if value else [])
        for target in values:
            if PeripheryInfo in target:
                providers.append(target[PeripheryInfo])
    return providers

def _force_indexstore_impl(settings, _attr):
    return {
        "//command_line_option:features": settings["//command_line_option:features"] + [
            "swift.index_while_building",
        ],
    }

force_indexstore = transition(
    implementation = _force_indexstore_impl,
    inputs = [
        "//command_line_option:features",
    ],
    outputs = [
        "//command_line_option:features",
    ],
)

def _scan_inputs_aspect_impl(target, ctx):
    swift_srcs = []
    indexstores = []
    test_targets = []
    plists = []
    xibs = []
    xcdatamodels = []
    xcmappingmodels = []

    if not target.label.workspace_name:  # Ignore external deps
        modules = []

        if SwiftBinaryInfo in target:
            modules.extend(target[SwiftBinaryInfo].swift_info.direct_modules)

        if SwiftInfo in target:
            modules.extend(target[SwiftInfo].direct_modules)

        for module in modules:
            if hasattr(module, "swift"):
                if hasattr(module.compilation_context, "direct_sources"):
                    swift_srcs.extend([src for src in module.compilation_context.direct_sources if src.extension == "swift"])

                if ctx.rule.attr.testonly:
                    test_targets.append(module.name)

                if hasattr(module.swift, "indexstore") and module.swift.indexstore:
                    indexstores.append(module.swift.indexstore)

        if AppleResourceInfo in target:
            # Each attribute has the structure '[(parent, resource_swift_module, resource_depset)]'
            info = target[AppleResourceInfo]

            if hasattr(info, "infoplists"):
                plists.extend(info.infoplists[0][2].to_list())

            if hasattr(info, "xibs"):
                xibs.extend(info.xibs[0][2].to_list())

            if hasattr(info, "storyboards"):
                # Periphery uses the same parser for xibs and storyboards.
                xibs.extend(info.storyboards[0][2].to_list())

            if hasattr(info, "datamodels"):
                # 'datamodels' contains both .xcdatamodel and .xcmappingmodel files.
                # We separate them because Periphery uses a different parser for each.
                resources = info.datamodels[0][2].to_list()

                for resource in resources:
                    if ".xcdatamodel" in resource.path:
                        xcdatamodels.append(resource)
                    elif ".xcmappingmodel" in resource.path:
                        xcmappingmodels.append(resource)

    providers = _periphery_info_providers(ctx.rule.attr)

    return [
        PeripheryInfo(
            swift_srcs = depset(
                swift_srcs,
                transitive = [provider.swift_srcs for provider in providers],
            ),
            indexstores = depset(
                indexstores,
                transitive = [provider.indexstores for provider in providers],
            ),
            plists = depset(
                direct = plists,
                transitive = [provider.plists for provider in providers],
            ),
            xibs = depset(
                direct = xibs,
                transitive = [provider.xibs for provider in providers],
            ),
            xcdatamodels = depset(
                direct = xcdatamodels,
                transitive = [provider.xcdatamodels for provider in providers],
            ),
            xcmappingmodels = depset(
                direct = xcmappingmodels,
                transitive = [provider.xcmappingmodels for provider in providers],
            ),
            test_targets = depset(
                direct = test_targets,
                transitive = [provider.test_targets for provider in providers],
            ),
        ),
    ]

scan_inputs_aspect = aspect(
    _scan_inputs_aspect_impl,
    attr_aspects = _TRANSITIVE_ATTRS,
)

def _shell_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"

def _collect_inputs(ctx):
    swift_srcs_set = sets.make()
    indexstores_set = sets.make()
    plists_set = sets.make()
    xibs_set = sets.make()
    xcdatamodels_set = sets.make()
    xcmappingmodels_set = sets.make()
    test_targets_set = sets.make()

    for dep in ctx.attr.deps:
        swift_srcs_set = sets.union(swift_srcs_set, sets.make(dep[PeripheryInfo].swift_srcs.to_list()))
        indexstores_set = sets.union(indexstores_set, sets.make(dep[PeripheryInfo].indexstores.to_list()))
        plists_set = sets.union(plists_set, sets.make(dep[PeripheryInfo].plists.to_list()))
        xibs_set = sets.union(xibs_set, sets.make(dep[PeripheryInfo].xibs.to_list()))
        xcdatamodels_set = sets.union(xcdatamodels_set, sets.make(dep[PeripheryInfo].xcdatamodels.to_list()))
        xcmappingmodels_set = sets.union(xcmappingmodels_set, sets.make(dep[PeripheryInfo].xcmappingmodels.to_list()))
        test_targets_set = sets.union(test_targets_set, sets.make(dep[PeripheryInfo].test_targets.to_list()))

    return struct(
        swift_srcs = sets.to_list(swift_srcs_set),
        indexstores = sets.to_list(indexstores_set),
        plists = sets.to_list(plists_set),
        xibs = sets.to_list(xibs_set),
        xcdatamodels = sets.to_list(xcdatamodels_set),
        xcmappingmodels = sets.to_list(xcmappingmodels_set),
        test_targets = sets.to_list(test_targets_set),
    )

def _write_project_config(ctx, inputs, path_for):
    indexstores_config = [path_for(file) for file in inputs.indexstores]
    if ctx.attr.global_indexstore:
        indexstores_config = [ctx.attr.global_indexstore]

    project_config = struct(
        indexstores = indexstores_config,
        plists = [path_for(file) for file in inputs.plists],
        xibs = [path_for(file) for file in inputs.xibs],
        xcdatamodels = [path_for(file) for file in inputs.xcdatamodels],
        xcmappingmodels = [path_for(file) for file in inputs.xcmappingmodels],
        test_targets = inputs.test_targets,
    )

    project_config_file = ctx.actions.declare_file(ctx.label.name + "_project_config.json")
    ctx.actions.write(project_config_file, json.encode_indent(project_config))
    return project_config_file

def _toolchain(ctx):
    return ctx.toolchains[TOOLCHAIN_TYPE]

def _data_runfiles(ctx):
    return [data[DefaultInfo].default_runfiles for data in ctx.attr.data]

def _scan_impl_common(ctx, is_test):
    # When invoked via `bazel test` the script runs from the runfiles
    # directory, so paths must be runfiles-relative (short_path). For
    # `bazel run` the script runs from the workspace root, where declared
    # outputs resolve through the bazel-out convenience symlink (path).
    path_for = (lambda file: file.short_path) if is_test else (lambda file: file.path)

    inputs = _collect_inputs(ctx)
    project_config_file = _write_project_config(ctx, inputs, path_for)

    toolchain = _toolchain(ctx)
    periphery = toolchain.periphery_files_to_run.executable

    scan_script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = scan_script,
        substitutions = {
            # Always a relative path, so that a binary in the main repo, whose
            # short path is a bare filename, is not looked up on PATH.
            "%periphery_path%": "./" + periphery.short_path,
            "%config_path%": path_for(ctx.file.config) if ctx.file.config else "",
            "%project_config_path%": path_for(project_config_file),
            "%periphery_args%": " ".join([_shell_quote(arg) for arg in ctx.attr.periphery_args]),
        },
        is_executable = True,
    )

    # Swift sources are not included in the generated project file, yet they
    # are referenced in the indexstores and will be read by Periphery, and
    # therefore must be present in the runfiles.
    runfiles_files = (
        inputs.swift_srcs + inputs.indexstores + inputs.plists + inputs.xibs +
        inputs.xcdatamodels + inputs.xcmappingmodels +
        [periphery, project_config_file] + ctx.files.data
    )

    if ctx.file.config:
        runfiles_files.append(ctx.file.config)

    runfiles = ctx.runfiles(files = runfiles_files)
    runfiles = runfiles.merge_all([toolchain.periphery_runfiles] + _data_runfiles(ctx))

    return DefaultInfo(
        executable = scan_script,
        runfiles = runfiles,
    )

# buildifier: disable=function-docstring
def scan_impl(ctx):
    return _scan_impl_common(ctx, is_test = False)

# buildifier: disable=function-docstring
def scan_test_impl(ctx):
    return _scan_impl_common(ctx, is_test = True)

# buildifier: disable=function-docstring
def scan_report_impl(ctx):
    inputs = _collect_inputs(ctx)
    project_config_file = _write_project_config(ctx, inputs, lambda file: file.path)

    report_file = ctx.actions.declare_file(ctx.label.name + ".report")

    args = ctx.actions.args()
    args.add("scan")
    args.add("--disable-update-check")

    # Result paths must be relative for the report to be reproducible; the
    # scan executes in a sandbox with a nondeterministic absolute path.
    args.add("--relative-results")
    args.add("--format", ctx.attr.format)
    args.add("--write-results", report_file.path)
    args.add("--generic-project-config", project_config_file.path)
    if ctx.file.config:
        args.add("--config", ctx.file.config.path)
    args.add_all(ctx.attr.periphery_args)

    action_inputs = (
        inputs.swift_srcs + inputs.indexstores + inputs.plists + inputs.xibs +
        inputs.xcdatamodels + inputs.xcmappingmodels +
        [project_config_file] + ctx.files.data
    )

    if ctx.file.config:
        action_inputs.append(ctx.file.config)

    ctx.actions.run(
        executable = _toolchain(ctx).periphery_files_to_run,
        arguments = [args],
        # Include the data targets' runfiles, matching what scan and scan_test
        # provide at run time.
        inputs = depset(
            action_inputs,
            transitive = [runfiles.files for runfiles in _data_runfiles(ctx)],
        ),
        outputs = [report_file],
        mnemonic = "PeripheryScan",
        progress_message = "Generating Periphery report for %{label}",
    )

    return [
        DefaultInfo(files = depset([report_file])),
        OutputGroupInfo(
            project_config = depset([project_config_file]),
        ),
    ]
