PROFILE=cmt-aioi-sso-user
REGION=us-west-2
LOG_GROUP="aioi-prod/vtrackserver-login"
LOG_GROUP1="/aws/lambda/aioi-prod-deauth-devices"

QUERY='
fields @timestamp, @message, @logStream, @log 
| filter (uri = "/mobile/v3/login_step2" and app_version like /^3\.0\.14/)
   or @message like "Retrieved registered devices for user:"
   or @message like "Successfully logged out device:"
| parse @message "Retrieved registered devices for user: *\"}\"" as deauth_target_short_user_id
| parse @message "Successfully logged out device: *\"}\"" as deauthed_device
| display @timestamp, uri, status_code, app_version,
          response_body.profile.short_user_id,
          deauth_target_short_user_id,
          deauthed_device,
          @message, @logStream, @log
| sort @timestamp asc
| limit 10000
'

while true; do
  END=$(date -u +%s)
  START=$(( END - 65*60 ))

  QID=$(aws logs start-query \
    --profile "$PROFILE" \
    --region "$REGION" \
    --log-group-names "$LOG_GROUP" "$LOG_GROUP1" \
    --start-time "$START" \
    --end-time "$END" \
    --query-string "$QUERY" \
    --query queryId \
    --output text)

  while true; do
    STATUS=$(aws logs get-query-results \
      --profile "$PROFILE" \
      --region "$REGION" \
      --query-id "$QID" \
      --query status \
      --output text)

    [[ "$STATUS" == "Complete" ]] && break
    sleep 1
  done

{
  echo -e "@timestamp\turi\tstatus_code\tapp_version\tshort_user_id\tdeauth_target_short_user_id\tdeauthed_device\t@message\t@logStream\t@log"
  aws logs get-query-results \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query-id "$QID" \
    --output json \
  | jq -r '
    .results[]
    | map({(.field): .value}) | add
    | [
        ."@timestamp",
        .uri,
        .status_code,
        .app_version,
        ."response_body.profile.short_user_id",
        .deauth_target_short_user_id,
        .deauthed_device,
        ."@message",
        ."@logStream",
        ."@log"
      ]
    | @tsv'
} | column -t -s $'\t'

  echo "---- refresh @ $(date -u) ----"
  sleep 30
done
