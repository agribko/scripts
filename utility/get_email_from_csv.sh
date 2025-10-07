#!/bin/bash

ESCALATION=${1:?Usage: $0 <csv_file>}

rg '利用者ID' "$ESCALATION" | awk -F',' '{print $2}' | pbcopy
