"""
Public Periphery Bazel rules.
"""

load("//bazel/internal/scan:scan.bzl", "force_indexstore", "scan_impl", "scan_inputs_aspect")

scan = rule(
    doc = "Scans the top-level deps and their transitive deps for unused code.",
    attrs = {
        "deps": attr.label_list(
            cfg = force_indexstore,
            mandatory = True,
            aspects = [scan_inputs_aspect],
            doc = "Top-level project targets to scan.",
        ),
        "license_store": attr.string(doc = "Path used to locate the license store."),
        "global_indexstore": attr.string(doc = "Path to a global index store."),
        "periphery_args": attr.string_list(doc = "Arguments forwarded to `periphery scan`."),
        "periphery": attr.label(
            doc = "The periphery executable target.",
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "_template": attr.label(
            allow_single_file = True,
            default = "@periphery_bazel_driver//bazel/internal/scan:scan_template.sh",
        ),
    },
    outputs = {
        "project_config": "project_config.json",
        "scan": "scan.sh",
    },
    implementation = scan_impl,
    executable = True,
)
