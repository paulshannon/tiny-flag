#!/usr/bin/env bash
# Run a native windowed client (fastest iteration loop — no export needed).
# Usage: tools/run_client.sh [game] [ws://host:port] [--bot]   (default: Protocol.DEFAULT_GAME)
source "$(dirname "$0")/_godot.sh"
cd "$ROOT"
ARGS=(--client)
[[ -n "${1:-}" ]] && ARGS+=(--game="$1")
[[ -n "${2:-}" ]] && ARGS+=(--url="$2")
[[ "${3:-}" == "--bot" ]] && ARGS+=(--bot)
exec "$GODOT" --path . -- "${ARGS[@]}"
