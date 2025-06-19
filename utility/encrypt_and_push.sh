#!/bin/bash
set -e

NOTES_DIR=~/docs/vimwiki/diary
ENCRYPTED_DIR=~/docs/vimwiki/encrypted
EMAIL="agribko@cmtelematics.com"

mkdir -p "$ENCRYPTED_DIR"

# Encrypt all markdown files
for file in "$NOTES_DIR"/*.md; do
    filename=$(basename "$file")
    gpg --yes --batch -o "$ENCRYPTED_DIR/$filename.gpg" -e -r "$EMAIL" "$file"
done

cd ~/docs/vimwiki
git add encrypted/
git commit -m "Update encrypted notes"
git push
