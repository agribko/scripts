#!/usr/bin/env zsh

source /Users/agribko/fzfstash.zsh
ESCALATION=${1:?Usage: $0 <xlsx_file>}

WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t escalation)"
CSV="$WORKDIR/escalation.csv"

ssconvert "$ESCALATION" "$CSV"

base=$(basename $ESCALATION .csv)
EXTRACTED=$(echo "$base" | grep -oE '【[^】]*】' | grep -oE 'S[0-9_]+') || true

LINK="$HOME/Downloads/$EXTRACTED"

ln -sf "$CSV" "$LINK"
STASH="$HOME/bin/stash" 
# Stash commands
$STASH "getcontent '$LINK'"
$STASH "gettag '$LINK'"
$STASH "getpolicy '$LINK'"
$STASH "getemail '$LINK'"
