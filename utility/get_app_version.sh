CSV=$1
xsv select 'last_app_version' "$CSV" | tail -1 | pbcopy
