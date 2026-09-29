#!/usr/bin/env bash
# Backwards-compatible entrypoint for the canonical DeFi integration demo.
# The old runner hard-coded stale container names and an invalid payload format;
# run_defi_demo.sh now owns the actual Vela v0.2.0 flow.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/run_defi_demo.sh" "$@"
