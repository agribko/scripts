#!/bin/bash

ESCALATION=${1:?Usage: $0 <csv_file>}

email=$(
#  rg -m1 '^利用者ID,' --no-line-number --color=never -- "$ESCALATION" \
#  | awk -F',' 'NR==1{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}'
rg '利用者ID' "$ESCALATION" | awk -F',' '{print $2}'
)

if [[ -z "${email:-}" ]]; then
  printf 'error: could not find email row (利用者ID)\n' >&2
  exit 1
fi

# Optional sanity check: looks like an email
if ! [[ "$email" =~ @ ]]; then
  printf 'error: extracted value does not look like an email: %s\n' "$email" >&2
  exit 2
fi

printf '%s\n' "$email"
