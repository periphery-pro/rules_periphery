#!/usr/bin/env bash
# Stub periphery binary that prints one argument per line, so tests can
# assert argv boundaries.
printf '%s\n' "$@"
