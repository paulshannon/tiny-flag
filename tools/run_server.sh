#!/usr/bin/env bash
# Run a headless game server from source. Ctrl-C to stop.
# Usage: tools/run_server.sh [game] [port]   (default: Protocol.DEFAULT_GAME)
source "$(dirname "$0")/_godot.sh"
cd "$ROOT"
ARGS=(--server)
[[ -n "${1:-}" ]] && ARGS+=(--game="$1")
[[ -n "${2:-}" ]] && ARGS+=(--port="$2")
exec "$GODOT" --headless --path . -- "${ARGS[@]}"
