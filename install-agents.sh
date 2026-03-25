#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STORE_DIR="$SCRIPT_DIR/agent_store"
RESOURCE_CONFIG="$SCRIPT_DIR/resource-setup.json"
AGENTS_DIR="$HOME/.kiro/agents"

for md in "$STORE_DIR"/*.md; do
  echo "Installing $(basename "$md")..."
  cao install "$md"
done

for agent_file in "$AGENTS_DIR"/*.json; do
  has_prompt=$(jq 'has("prompt")' "$agent_file")
  res_len=$(jq '.resources // [] | length' "$agent_file")
  if [[ "$has_prompt" == "false" && "$res_len" -gt 0 ]]; then
    tmp=$(mktemp)
    jq '.prompt = .resources[0] | .resources = .resources[1:]' "$agent_file" > "$tmp"
    mv "$tmp" "$agent_file"
    echo "MOVED first resource to prompt: $agent_file"
  fi
done

if [[ ! -f "$RESOURCE_CONFIG" ]]; then
  echo "No resource-setup.json found, skipping resource injection."
  exit 0
fi

agents=$(jq -r '.agents | keys[]' "$RESOURCE_CONFIG")

for agent in $agents; do
  agent_file="$AGENTS_DIR/${agent}.json"
  if [[ ! -f "$agent_file" ]]; then
    echo "SKIP: $agent_file does not exist"
    continue
  fi

  resources=$(jq -r --arg a "$agent" '.agents[$a][]' "$RESOURCE_CONFIG")
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
