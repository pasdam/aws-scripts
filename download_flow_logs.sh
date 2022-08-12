#!/usr/bin/env bash

print_usage() {
  SCRIPT_NAME=$(basename "$0")
  echo "Usage: $SCRIPT_NAME <aws-profile> <log-group> <from> <to>"
  echo "Example: $SCRIPT_NAME"
  echo "Parameters:"
  echo "  aws-profile  AWS profile to use"
  echo "  log-group    Name of the log group to download"
  echo "  from         Timestamp (Unix epoch in milliseconds) of the date and time from which download the logs"
  echo "  to           Timestamp (Unix epoch in milliseconds) of the date and time up to which download the logs"
  exit "$1"
}

AWS_PROFILE=$1
if [ -z "$AWS_PROFILE" ]; then
  1>&2 echo "Please specify the AWS profile as first parameter"
  exit 1
fi

LOG_GROUP=$2
if [ -z "$LOG_GROUP" ]; then
  1>&2 echo "Please specify the log group as second parameter"
  exit 2
fi

FROM=$3
if [ -z "$FROM" ]; then
  1>&2 echo "Please specify the timestamp (Unix epoch in milliseconds) from which retrieve the logs as third parameter"
  exit 3
fi

TO=$4
if [ -z "$TO" ]; then
  1>&2 echo "Please specify the timestamp (Unix epoch in milliseconds) to which retrieve the logs as forth parameter"
  exit 4
fi


export AWS_PAGER="" # Disable pagination
export AWS_REGION=me-south-1

INSTANCES=$(aws ec2 describe-instances --filters Name=instance-state-code,Values=16 | jq '[.Reservations[] | .Instances[]]')
while IFS= read -r instance_id; do
  INTERFACES=$(echo "$INSTANCES" | jq '[.[] | select(.InstanceId == "'"$instance_id"'") | .NetworkInterfaces[]]')

  while IFS= read -r interface_id; do

    LOG_FILE="./${instance_id}_${interface_id}_${FROM}.log"
    echo -n "" > "$LOG_FILE"


    LAST_TOKEN="last"
    CURRENT_TOKEN=""
    while [ "$LAST_TOKEN" != "$CURRENT_TOKEN" ]; do
      LAST_TOKEN=$CURRENT_TOKEN
      echo "Processing token: $CURRENT_TOKEN"
      if [ -n "$CURRENT_TOKEN" ]; then
        CURRENT_TOKEN="--next-token $CURRENT_TOKEN"
      fi
      LOGS=$(aws logs get-log-events $CURRENT_TOKEN --log-group-name "$LOG_GROUP" --log-stream-name "$interface_id"-all --start-time "$FROM" --end-time "$TO")
      CURRENT_TOKEN=$(echo "$LOGS" | jq -r '.nextForwardToken')
      echo "$LOGS" | jq -c -r '.events[] | .message' | sed "s/$INTERFACE_NAME //" >> "$LOG_FILE"
    done

  done < <(echo "$INTERFACES" | jq -c -r '.[] | .NetworkInterfaceId')
done < <(echo "$INSTANCES" | jq -c -r '.[] | .InstanceId')
exit 0

echo "Log stream name: $LOG_STREAM"
echo "Interface name: $INTERFACE_NAME"
