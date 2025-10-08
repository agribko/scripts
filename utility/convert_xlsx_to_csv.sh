#!/bin/bash

ESCALATION=${1:?Usage: $0 <xlsx_file>}
TEMP_FILE=temp_file_$(uuidgen).csv

cd /Users/agribko/Downloads

ssconvert "$ESCALATION" $TEMP_FILE

echo "✅ Escalation file converted to $TEMP_FILE and copied to clipboard"

echo "$TEMP_FILE" | pbcopy
