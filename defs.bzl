"""
Public macro for defining a runnable Periphery scan target.
"""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

def periphery(
        name,
        query = None,
        filter = None,
        global_indexstore = None,
        check_visibility = False,
        bazel_args = [],
        periphery_args = [],
        **kwargs):
    """Defines a runnable target that scans the workspace for unused code.

    Running the target with `bazel run //:<name>` discovers the workspace's
    top-level targets, generates a hidden scan target, and invokes
    `periphery scan --generic-project-config` through a nested `bazel run`.

    Args:
        name: The target name. Choose anything you like, e.g. "periphery".
        query: Overrides the default top-level target query.
        filter: Filter pattern applied to the default top-level target query.
        global_indexstore: Path to a global index store populated by Bazel.
        check_visibility: Whether to run the scan with Bazel visibility checking.
        bazel_args: Extra arguments forwarded to the nested `bazel run`.
        periphery_args: Arguments forwarded to `periphery scan`.
        **kwargs: Additional arguments for the underlying runnable target
            (e.g. `visibility`, `tags`).
    """

    # Scalar configuration is passed via the environment so values containing
    # spaces or shell metacharacters (notably `query`) survive intact.
    env = {}
    if query:
        env["PERIPHERY_QUERY"] = query
    if filter:
        env["PERIPHERY_FILTER"] = filter
    if global_indexstore:
        env["PERIPHERY_GLOBAL_INDEXSTORE"] = global_indexstore
    if check_visibility:
        env["PERIPHERY_CHECK_VISIBILITY"] = "true"

    args = []
    for arg in bazel_args:
        args.extend(["--bazel-arg", arg])
    if periphery_args:
        args.append("--")
        args.extend(periphery_args)

    sh_binary(
        name = name,
        srcs = ["@rules_periphery//tools:periphery-bazel"],
        env = env,
        args = args,
        **kwargs
    )
