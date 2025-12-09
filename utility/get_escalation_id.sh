#!/usr/bin/env bash
set -euo pipefail

input=${1:-}
if [[ -z "$input" ]]; then
  echo "Usage: $(basename "$0") <filename>" >&2
  exit 2
fi

base=$(basename "$input")

# Extract the inner text between 【 and 】. If not present, fall back to the base name (no extension).
extracted=$(printf '%s' "$base" | sed -E 's/.*【([^】]*)】.*/\1/')
if [[ "$extracted" == "$base" ]]; then
  extracted="${base%.*}"
fi

# Trim leading/trailing whitespace (just in case)
extracted=$(printf '%s' "$extracted" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# Copy to macOS clipboard
printf '%s' "$extracted" | pbcopy
