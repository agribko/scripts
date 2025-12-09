# on your local machine
# Get both hostname and credential in a single call from the vault
ITEM_JSON=$(op item get VisualDrive-prod-station --reveal --format json)

# hostname
HNAME=$(jq -r '.fields[] | select(.label=="hostname") | .value' <<< "$ITEM_JSON")
# apikey
PASSWD=$(jq -r '.fields[] | select(.label=="credential") | .value' <<< "$ITEM_JSON")

# Write both to a single file atomically
printf "%s\n" "$HNAME" > ~/Downloads/host.txt
printf "%s\n" "$PASSWD" > ~/Downloads/api_key.txt
