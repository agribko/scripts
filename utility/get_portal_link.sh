#!/usr/bin/env bash
set -euo pipefail

SHORT_ID=${1:?"Usage: $0 <short_id>"}
printf 'Driver Profile:\n https://my-aioi-prod.cmtelematics.com/viewDriver.php?userid=%s\n' "$SHORT_ID" | pbcopy
