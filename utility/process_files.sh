#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="/Users/agribko/tag_data_analysis_2023"

cd "$DEST_DIR"

# Loop over all xlsx files in destination directory
for ESCALATION in ./*.xlsx; do
    # If no xlsx files exist, the glob stays literal; skip
    [ -e "$ESCALATION" ] || continue

    echo "Processing: $ESCALATION"

    base=$(basename "$ESCALATION")

    # Extract S... from the part inside 【...】
    extracted_tag=$(echo "$base" \
        | grep -oE '【[^】]*】' \
        | grep -oE 'S[0-9_]+' \
        || true)

    if [ -z "${extracted_tag:-}" ]; then
        echo "  ⚠️  No S-tag found in '$base', skipping."
        continue
    fi

    EXTRACTED="${extracted_tag}.csv"
    TXT_FILE="${extracted_tag}.txt"

    # Convert xlsx → csv
    ssconvert "$ESCALATION" "$EXTRACTED"

    # Extract only the relevant part into a txt file
    awk '/ご回答欄/,0' "$EXTRACTED" > "$TXT_FILE"

    # Remove email addresses from the extracted text
    # (strip the username part before '@')
    sed -i '' -E 's/[[:alnum:]._%+-]+@//g' "$TXT_FILE"

    # Optionally remove the CSV as well; uncomment if you only want TXT:
     rm -f "$EXTRACTED"

    # Delete the processed xlsx file
    rm -f "$ESCALATION"

    echo "  Done → CSV: $EXTRACTED, TXT: $TXT_FILE (xlsx removed)"
done
