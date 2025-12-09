CSV=$1
xsv select 'platform_version' "$CSV" | tail -1 | pbcopy
