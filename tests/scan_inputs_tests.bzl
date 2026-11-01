"""Regression tests for Core Data resources exposed by rules_apple."""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
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

def _legacy_scanner_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = executable, target_file = ctx.file.src, is_executable = True)
    return [DefaultInfo(executable = executable)]

legacy_scanner = rule(
    implementation = _legacy_scanner_impl,
    executable = True,
    attrs = {"src": attr.label(allow_single_file = True)},
)
