#!/bin/bash

ESCALATION=${1:?Usage: $0 <csv_file>}

awk '/ご報告内容/,/折返しNG日時/' "$ESCALATION" | pbcopy
