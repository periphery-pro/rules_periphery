"""Regression tests for Core Data resources exposed by rules_apple."""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_apple//apple:resources.bzl", resources = "resources_common")
load("//internal:scan.bzl", "PeripheryInfo", "scan_inputs_aspect")

def _model_resources_impl(ctx):
    files = []
    for path in ctx.attr.paths:
        resource = ctx.actions.declare_file(ctx.label.name + "/" + path)
        ctx.actions.write(resource, "")
        files.append(resource)
    return [resources.bucketize_typed(
        resources = files,
        bucket_type = "datamodels",
        parent_dir_param = partial.make(lambda resource: resource.dirname),
    )]

model_resources = rule(
    implementation = _model_resources_impl,
    attrs = {"paths": attr.string_list()},
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
