#!/usr/bin/env bash
set -euo pipefail

# Defaults (override via flags if you want)
LOG_GROUP="aioi-stg/impact"
PROFILE="cmt-staging-sso-user"
REGION="us-west-2"
LIMIT=1000

# Fixed second filter
BUCKET_TEXT="notification to bucket cmt-st-mimamoru-kuruma-crash"

# Time selection (default: last 1 hour)
LOOKBACK="1h" # formats: 30m, 2h, 1d
DATE_JST=""   # YYYY-MM-DD (interpreted as JST day)

export AWS_PAGER="" # don't page output

usage() {
    cat >&2 <<EOF
Usage:
  $(basename "$0") [options] <impact_id> [impact_id2 ...]
  $(basename "$0") [options] "5,399,973,288,966,471" 5399973288966472 ...

Options:
  -l, --lookback <Nh|Nm|Nd|Ns>   Look back from now (default: 1h)
                                Examples: 30m, 2h, 3h, 1d
  -d, --date <YYYY-MM-DD>       Search that *JST* calendar day (00:00-24:00 JST)
                                Example: -d 2025-12-22
  -n, --limit <N>               Max results (default: 1000)

  -g, --log-group <name>        Override log group
  -p, --profile <name>          Override AWS profile
  -r, --region <name>           Override AWS region
  -h, --help                    Show help

Notes:
- IDs are cleaned to digits only (commas removed).
- Multiple IDs are OR'd together in the regex: /id1|id2|id3/
EOF
}

# ---- Parse args ----
while [[ $# -gt 0 ]]; do
    case "$1" in
    -l | --lookback)
        LOOKBACK="${2:-}"
        shift 2
        ;;
    -d | --date)
        DATE_JST="${2:-}"
        shift 2
        ;;
    -n | --limit)
        LIMIT="${2:-}"
        shift 2
        ;;

    -g | --log-group)
        LOG_GROUP="${2:-}"
        shift 2
        ;;
    -p | --profile)
        PROFILE="${2:-}"
        shift 2
        ;;
    -r | --region)
        REGION="${2:-}"
        shift 2
        ;;

    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    -*)
        echo "Unknown option: $1" >&2
        usage
        exit 2
        ;;
    *) break ;;
    esac
done

if [[ $# -lt 1 ]]; then
    echo "Error: provide at least one impact id." >&2
    usage
    exit 2
fi

# ---- Build ID regex (strip commas/non-digits; join with |) ----
clean_ids=()
for raw in "$@"; do
    cleaned="$(printf "%s" "$raw" | tr -cd '0-9')"
    if [[ -n "$cleaned" ]]; then
        clean_ids+=("$cleaned")
    fi
done

if [[ ${#clean_ids[@]} -eq 0 ]]; then
    echo "Error: no usable numeric IDs after cleaning input." >&2
    exit 2
fi

ID_REGEX="$(
    IFS='|'
    echo "${clean_ids[*]}"
)"

# ---- Time window ----
END="$(date -u +%s)"
START=""

# Helper: detect GNU date support for -d (Linux); otherwise use BSD date (macOS)
have_gnu_date() {
    date -u -d "1970-01-01" +%s >/dev/null 2>&1
}

if [[ -n "$DATE_JST" ]]; then
    # Interpret as JST day boundaries: 00:00 JST to 24:00 JST
    if have_gnu_date; then
        START="$(TZ=Asia/Tokyo date -d "${DATE_JST} 00:00:00" +%s)"
    else
        START="$(TZ=Asia/Tokyo date -j -f "%Y-%m-%d %H:%M:%S" "${DATE_JST} 00:00:00" +%s)"
    fi
    END="$((START + 86400))"
else
    if [[ "$LOOKBACK" =~ ^([0-9]+)([smhd])$ ]]; then
        n="${BASH_REMATCH[1]}"
        u="${BASH_REMATCH[2]}"
        case "$u" in
        s) delta="$n" ;;
        m) delta=$((n * 60)) ;;
        h) delta=$((n * 3600)) ;;
        d) delta=$((n * 86400)) ;;
        esac
    else
        echo "Error: invalid lookback '$LOOKBACK' (use e.g. 30m, 2h, 1d)." >&2
        exit 2
    fi
    START="$((END - delta))"
fi

# ---- Logs Insights query (outputs @message only) ----
QUERY=$(
    cat <<EOF
fields @timestamp, @message
| filter @message like /$ID_REGEX/
| filter @message like /$BUCKET_TEXT/
| sort @timestamp desc
| display @message
| limit $LIMIT
EOF
)

# ---- Run query ----
QID="$(
    aws logs start-query \
        --profile "$PROFILE" \
        --region "$REGION" \
        --log-group-names "$LOG_GROUP" \
        --start-time "$START" \
        --end-time "$END" \
        --query-string "$QUERY" \
        --query queryId \
        --output text
)"

# ---- Wait for completion ----
while true; do
    STATUS="$(
        aws logs get-query-results \
            --profile "$PROFILE" \
            --region "$REGION" \
            --query-id "$QID" \
            --query status \
            --output text
    )"

    case "$STATUS" in
    Complete) break ;;
    Failed | Cancelled)
        echo "Query $STATUS (queryId=$QID)" >&2
        exit 1
        ;;
    Running | Scheduled) sleep 1 ;;
    *) sleep 1 ;;
    esac
done

# ---- Print messages only (stdout) ----
aws logs get-query-results \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query-id "$QID" \
    --output json |
    jq -r '.results[][] | select(.field == "@message") | .value'
