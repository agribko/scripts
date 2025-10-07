#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd /Users/agribko/gdrive

rclone copy "gdrive:テンプレート/" ./

mkdir -p templates

for file in *.docx; do
    [ -f "$file" ] || continue

    echo "--- Processing: $file ---"

    base=$(basename "$file" .docx)
    docx2txt.sh "$file"

    txtfile="${base}.txt"

    # Allow grep to fail without breaking the loop
    extracted=$(echo "$base" | grep -oE '【[^】]*】' | grep -oE 'S[0-9_]+') || true

    if [[ -z "${extracted:-}" ]]; then
        extracted="${base// /_}"
    fi

    sed -i '' -E 's/[[:alnum:]._%+-]+@//g' "$txtfile"
    if [ -f "$txtfile" ]; then
        echo "Moving $txtfile → templates/${extracted}.txt"
        mv "$txtfile" "templates/${extracted}.txt"
    else
        echo "❌ Warning: $txtfile not found after conversion"
    fi

    echo "Processed: $file"
done
