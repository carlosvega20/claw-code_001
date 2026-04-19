#!/bin/bash
# bonsai.sh — run claw-code backed by your local bonsai_core_001 API
#
# Requirements:
#   1. bonsai_core_001 running: cd ~/code/bonsai_core_001 && bash start.sh
#   2. claw binary built:       cd rust && cargo build --release
#
# Usage:
#   bash bonsai.sh "create a fastapi hello world"
#   bash bonsai.sh --dangerously-skip-permissions "refactor main.py"

set -a  # export all variables

# ── Point claw-code at the local bonsai API ──────────────────────────────────
export ANTHROPIC_BASE_URL="http://localhost:9001"
export ANTHROPIC_API_KEY="bonsai-local"
export ANTHROPIC_MODEL="${BONSAI_MODEL:-bonsai-2bit}"   # override: BONSAI_MODEL=ollama:llama3.2

set +a

BINARY="$(dirname "$0")/rust/target/release/claw"
if [ ! -f "$BINARY" ]; then
    BINARY="$(dirname "$0")/rust/target/debug/claw"
fi

if [ ! -f "$BINARY" ]; then
    echo "claw binary not found. Build it first:"
    echo "  cd $(dirname "$0")/rust && cargo build --release"
    exit 1
fi

exec "$BINARY" "$@"
