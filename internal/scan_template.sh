#!/usr/bin/env bash
set -euo pipefail

args=(scan --generic-project-config "%project_config_path%")

if [ -n "%config_path%" ]; then
    args+=(--config "%config_path%")
fi

exec "%periphery_path%" "${args[@]}" %periphery_args% "$@"
