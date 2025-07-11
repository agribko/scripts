#!/bin/bash

set -euo pipefail

#cd /Users/agribko/gdrive
cd /Users/agribko/gd

# Sync from Google Drive folder テンプレート to current dir
rclone copy "gdrive:テンプレート/" ./

mkdir -p templates

# Process all .docx files
for file in *.docx; do
    [ -f "$file" ] || continue

    echo "Processing: $file"
    # Convert docx to txt
    docx2txt.sh "$file" 

    # Extract filename like S0626_10163 from: 回答【エスカレーション・S0626_10163】.docx
    base=$(basename "$file" .docx)

    # Use regex to extract S0626_10163 from inside 【】
    extracted=$(echo "$base" | grep -oE '【[^】]*】' | grep -oE 'S[0-9_]+')

    # If nothing matched, fallback to original base
    if [[ -z "$extracted" ]]; then
        extracted="${base// /_}"  # replace spaces with underscores just in case
    fi

    # Move txt file with new name
    txtfile="${file%.docx}.txt"
    if [ -f "$txtfile" ]; then
        echo "Moving $txtfile → templates/${extracted}.txt"
        mv "$txtfile" "templates/${extracted}.txt"
    else
        echo "❌ Warning: $txtfile not found after conversion"
    fi
done
