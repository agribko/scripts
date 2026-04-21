#!/usr/bin/env zsh

source /Users/agribko/fzfstash.zsh
TICKET=${1:?Usage $0 <ticket> <file>}
ESCL_IN=${2:?Usage $0 <ticket> <file>}

base=$(basename $ESCL_IN)
EXTRACTED=$(echo "$base" | grep -oE '【[^】]*】' | grep -oE 'S[0-9_]+') || true
export CMD_STASH_TRAY="$EXTRACTED"

ESCL="$HOME/Downloads/$ESCL_IN"
[[ -f "$ESCL" ]] || { echo "Not in Downloads: $ESCL" >&2; exit 1; }

STASH="$HOME/bin/stash" 

/Users/agribko/scripts/utility/copy_to_gdrive.sh "$TICKET" "$ESCL"
/Users/agribko/scripts/utility/convert_xlsx_to_csv.sh "$ESCL"


# Stash handy actions (quote safely)
STASH="${STASH:-$HOME/bin/stash}"
"$STASH" "copyandzip '$TICKET' '$ESCL_IN' MSAD"
