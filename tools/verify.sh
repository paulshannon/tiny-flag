#!/usr/bin/env bash
# The "definition of done" from CLAUDE.md in one command:
#   scripts compile → unit tests pass → server + 2 bot clients work in every game (smoke.sh all)
#   → bots survive a server restart.
set -euo pipefail
cd "$(dirname "$0")"
./check.sh
./test.sh
./smoke.sh all "${1:-8}" 2
SMOKE_RESTART=1 ./smoke.sh flag "${1:-8}" 2
echo "VERIFY: PASS"
