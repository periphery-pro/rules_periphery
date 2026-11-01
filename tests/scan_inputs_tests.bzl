"""Regression tests for resources exposed by rules_apple."""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_apple//apple:providers.bzl", "AppleResourceInfo")
load("@rules_apple//apple:resources.bzl", resources = "resources_common")
load("//internal:scan.bzl", "PeripheryInfo", "scan_inputs_aspect")

def _model_resources_impl(ctx):
    files = []
    for path in ctx.attr.paths:
        resource = ctx.actions.declare_file(ctx.label.name + "/" + path)
        if path.endswith("/contents"):
            contents = '<model><attribute customClassName="CustomTransformer"/></model>'
        elif path.endswith("/xcmapping.xml"):
            contents = '<database><attribute name="migrationpolicyclassname">CustomMigrationPolicy</attribute></database>'
        else:
            contents = "metadata, not model XML"
        ctx.actions.write(resource, contents)
        files.append(resource)
    for path in ctx.attr.trees:
        resource = ctx.actions.declare_directory(ctx.label.name + "/" + path)
        mapping = resource.extension == "xcmappingmodel"
        ctx.actions.run_shell(
            outputs = [resource],
            arguments = [
                resource.path,
                "V1.xcdatamodel" if resource.extension == "xcdatamodeld" else "",
                '<database><attribute name="migrationpolicyclassname">CustomMigrationPolicy</attribute></database>' if mapping else '<model><attribute customClassName="CustomTransformer"/></model>',
                "xcmapping.xml" if mapping else "contents",
            ],
            command = 'mkdir -p "$1/$2"; printf "%s" "$3" > "$1/$2/$4"',
        )
        files.append(resource)
    return [resources.bucketize_typed(
        resources = files,
        bucket_type = "datamodels",
        parent_dir_param = partial.make(lambda resource: resource.dirname),
    )]

model_resources = rule(
    implementation = _model_resources_impl,
    attrs = {
        "paths": attr.string_list(),
        "trees": attr.string_list(),
    },
)

def _core_data_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[PeripheryInfo]
    prefix = target.label.package + "/" + target.label.name + "/"
    asserts.equals(env, [prefix + path for path in ctx.attr.models], [file.short_path for file in info.xcdatamodels.to_list()])
    asserts.equals(env, [prefix + path for path in ctx.attr.mappings], [file.short_path for file in info.xcmappingmodels.to_list()])
    return analysistest.end(env)

core_data_inputs_test = analysistest.make(
    _core_data_inputs_test_impl,
    attrs = {
        "models": attr.string_list(),
        "mappings": attr.string_list(),
    },
    extra_target_under_test_aspects = [scan_inputs_aspect],
)

def _interface_builder_resources_impl(ctx):
    providers = []
    for bucket_type in ["xibs", "storyboards"]:
        files = []
        for path in getattr(ctx.attr, bucket_type):
            resource = ctx.actions.declare_file(ctx.label.name + "/" + path)
            class_name = path.replace("/", "_").replace(".", "_")
            ctx.actions.write(resource, '<document><view customClass="%s"/></document>' % class_name)
            files.append(resource)
        providers.append(resources.bucketize_typed(
            resources = files,
            bucket_type = bucket_type,
            parent_dir_param = partial.make(lambda resource: resource.dirname),
        ))
    return [resources.merge_providers(providers = providers)]

interface_builder_resources = rule(
    implementation = _interface_builder_resources_impl,
    attrs = {
        "xibs": attr.string_list(),
        "storyboards": attr.string_list(),
    },
)

def _interface_builder_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    resources_info = target[AppleResourceInfo]

    # Ensure the fixtures exercise distinct provider groups, not just several
    # files merged into one group by rules_apple.
    asserts.equals(env, ctx.attr.xib_groups, len(getattr(resources_info, "xibs", [])))
    asserts.equals(env, ctx.attr.storyboard_groups, len(getattr(resources_info, "storyboards", [])))
    prefix = target.label.package + "/" + target.label.name + "/"
    asserts.equals(
        env,
        sorted([prefix + path for path in ctx.attr.paths]),
        sorted([file.short_path for file in target[PeripheryInfo].xibs.to_list()]),
    )
    return analysistest.end(env)

interface_builder_inputs_test = analysistest.make(
    _interface_builder_inputs_test_impl,
    attrs = {
        "paths": attr.string_list(),
        "xib_groups": attr.int(),
        "storyboard_groups": attr.int(),
    },
    extra_target_under_test_aspects = [scan_inputs_aspect],
)

def _legacy_scanner_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = executable, target_file = ctx.file.src, is_executable = True)
    return [DefaultInfo(executable = executable)]

legacy_scanner = rule(
    implementation = _legacy_scanner_impl,
    executable = True,
    attrs = {"src": attr.label(allow_single_file = True)},
)
