#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STORE_DIR="$SCRIPT_DIR/agent_store"

for md in "$STORE_DIR"/*.md; do
  echo "Installing $(basename "$md")..."
  cao install "$md"
done

echo "Done."
