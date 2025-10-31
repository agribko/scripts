#!/usr/bin/env zsh

TICKET=${1:?Usage $0 <ticket> <file>}
ESCL_IN=${2:?Usage $0 <ticket> <file>}

ESCL="$HOME/Downloads/$ESCL_IN"
[[ -f "$ESCL" ]] || { echo "Not in Downloads: $ESCL" >&2; exit 1; }

STASH="$HOME/bin/stash" 

/Users/agribko/scripts/utility/copy_to_gdrive.sh "$TICKET" "$ESCL"
/Users/agribko/scripts/utility/convert_xlsx_to_csv.sh "$ESCL"

$STASH "copyandzip '$TICKET' '$ESCL' MSAD"
