"""
Public Periphery Bazel rules.
"""

load(
    "//internal:scan.bzl",
    "TOOLCHAIN_TYPE",
    "force_indexstore",
    "scan_impl",
    "scan_inputs_aspect",
    "scan_report_impl",
    "scan_test_impl",
)

_COMMON_ATTRS = {
    "config": attr.label(
        allow_single_file = True,
        doc = "The .periphery.yml configuration file to scan with.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional files needed by the scan, e.g. a baseline referenced by `periphery_args`.",
    ),
    "deps": attr.label_list(
        cfg = force_indexstore,
        mandatory = True,
        aspects = [scan_inputs_aspect],
        doc = "Top-level project targets to scan.",
    ),
    "global_indexstore": attr.string(doc = "Path to a global index store."),
    "periphery_args": attr.string_list(doc = "Arguments forwarded to `periphery scan`."),
}

scan = rule(
    doc = "Scans the top-level deps and their transitive deps for unused code when run with `bazel run`.",
    attrs = _COMMON_ATTRS | {
        "_template": attr.label(
            allow_single_file = True,
            default = "@rules_periphery//internal:scan_template.sh",
        ),
    },
    implementation = scan_impl,
    executable = True,
    toolchains = [TOOLCHAIN_TYPE],
)

scan_test = rule(
    doc = """\
Scans the top-level deps and their transitive deps for unused code as a test target.

The test fails if Periphery reports any unused declarations (`--strict` is enabled).
Use this rule to run Periphery in CI via `bazel test`.\
""",
    attrs = _COMMON_ATTRS | {
        "_template": attr.label(
            allow_single_file = True,
            default = "@rules_periphery//internal:scan_test_template.sh",
        ),
    },
    implementation = scan_test_impl,
    test = True,
    toolchains = [TOOLCHAIN_TYPE],
)

_REPORT_FORMATS = [
    "xcode",
    "csv",
    "json",
    "checkstyle",
    "codeclimate",
    "github-actions",
    "github-markdown",
    "gitlab-codequality",
]

scan_report = rule(
    doc = """\
Scans the top-level deps and their transitive deps for unused code and writes the
formatted report to a file output.

Unlike `scan` and `scan_test`, this rule runs Periphery at build time and exposes
the report as a regular Bazel file artifact, so it can be consumed by other rules
via `data` deps or `srcs`.\
""",
    attrs = _COMMON_ATTRS | {
        "format": attr.string(
            doc = "Output format for the report. One of: " + ", ".join(_REPORT_FORMATS) + ".",
            default = "json",
            values = _REPORT_FORMATS,
        ),
    },
    implementation = scan_report_impl,
    toolchains = [TOOLCHAIN_TYPE],
)
