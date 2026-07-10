#!/usr/bin/env bash
set -euo pipefail

args=(scan --generic-project-config "%project_config_path%")

if [ -n "%license_store_path%" ]; then
    args+=(--license-store "%license_store_path%")
fi

if [ -n "%config_path%" ]; then
    args+=(--config "%config_path%")
fi

exec "%periphery_path%" "${args[@]}" %periphery_args% "$@"
