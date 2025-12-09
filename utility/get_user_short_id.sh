#!/usr/bin/env bash
set -euo pipefail

# Usage: script.sh <user_email>
UEMAIL="${1:?Usage: $0 <csv_file>}"

# Fetch the 1Password item once unless ITEM_JSON is already exported in the env.
if [[ -z "${ITEM_JSON:-}" ]]; then
  ITEM_JSON="$(op item get Aioirecorder-prod-station --reveal --format json)"
fi

# Extract hostname and API key
HNAME="$(jq -r '.fields[] | select(.label=="hostname")  | .value'  <<<"$ITEM_JSON")"
PASSWD="$(jq -r '.fields[] | select(.label=="credential") | .value' <<<"$ITEM_JSON")"

if [[ -z "$HNAME" || -z "$PASSWD" ]]; then
  echo "Failed to extract hostname or credential from 1Password item." >&2
  exit 1
fi

# Build a proper JSON body with the email quoted and safely escaped
BODY="$(jq -n --arg email "$UEMAIL" '{users: [{account_id: $email}]}' )"

# Call the endpoint
curl -sS --fail-with-body -X POST "https://$HNAME/station/v4/get_users_and_vehicles" \
  -H "X-Cmt-Api-Key: $PASSWD" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
| jq -r '.. | .short_user_id? // empty'
