#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STORE_DIR="$SCRIPT_DIR/agent_store"
CONFIG="$SCRIPT_DIR/skill-setup.json"
AGENTS_DIR="$HOME/.kiro/agents"

# --- Step 1: Install agents from agent_store ---
for md in "$STORE_DIR"/*.md; do
  echo "Installing $(basename "$md")..."
  cao install "$md"
done

# --- Step 2: Add resources from skill-setup.json ---
if [[ ! -f "$CONFIG" ]]; then
  echo "No skill-setup.json found, skipping resource injection."
  exit 0
fi

agents=$(jq -r '.agents | keys[]' "$CONFIG")

for agent in $agents; do
  agent_file="$AGENTS_DIR/${agent}.json"
  if [[ ! -f "$agent_file" ]]; then
    echo "SKIP: $agent_file does not exist"
    continue
  fi

  resources=$(jq -r --arg a "$agent" '.agents[$a][]' "$CONFIG")
  changed=false

  for resource in $resources; do
    exists=$(jq -r --arg r "$resource" '.resources // [] | map(select(. == $r)) | length' "$agent_file")
    if [[ "$exists" -eq 0 ]]; then
      tmp=$(mktemp)
      jq --arg r "$resource" '.resources = ((.resources // []) + [$r])' "$agent_file" > "$tmp"
      mv "$tmp" "$agent_file"
      echo "ADDED: $resource -> $agent_file"
      changed=true
    else
      echo "EXISTS: $resource in $agent_file"
    fi
  done

  if [[ "$changed" == false ]]; then
    echo "NO CHANGE: $agent_file"
  fi
done

echo "Done."
