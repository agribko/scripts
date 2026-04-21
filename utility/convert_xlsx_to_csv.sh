#!/usr/bin/env zsh

source /Users/agribko/fzfstash.zsh
ESCALATION=${1:?Usage: $0 <xlsx_file>}

WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t escalation)"
CSV="$WORKDIR/escalation.csv"

ssconvert "$ESCALATION" "$CSV"

base=$(basename $ESCALATION)
EXTRACTED=$(echo "$base" | grep -oE '【[^】]*】' | grep -oE 'S[0-9_]+').csv || true

#export CMD_STASH_TRAY="$EXTRACTED"

LINK="$HOME/Downloads/$EXTRACTED"

ln -sf "$CSV" "$LINK"
STASH="$HOME/bin/stash" 
# Stash commands
$STASH "gettag '$LINK'"
$STASH "getescid '$ESCALATION'"
$STASH "getpolicy '$LINK'"
$STASH "getcontent '$LINK'"
$STASH "getemail '$LINK'"
$STASH "rm '$LINK'"
