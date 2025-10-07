#!/bin/bash

ESCALATION=${1:?Usage: $0 <csv_file>}

rg '証券番号' "$ESCALATION" | awk -F',' '{print $2}' | pbcopy
