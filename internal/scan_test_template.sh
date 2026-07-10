#!/usr/bin/env bash
set -euo pipefail

cd "${TEST_SRCDIR}/${TEST_WORKSPACE}"

args=(scan --strict --disable-update-check --project-root "$PWD" --generic-project-config "%project_config_path%")

# The workspace root isn't known at analysis time, so the license store
# location may instead be provided at runtime, e.g. via
# `--test_env=PERIPHERY_LICENSE_STORE=/path/to/project`.
license_store="${PERIPHERY_LICENSE_STORE:-%license_store_path%}"
if [ -n "$license_store" ]; then
    args+=(--license-store "$license_store")
fi

if [ -n "%config_path%" ]; then
    args+=(--config "%config_path%")
fi

exec "%periphery_path%" "${args[@]}" %periphery_args%
