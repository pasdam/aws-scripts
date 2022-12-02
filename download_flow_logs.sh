#!/usr/bin/env bash

print_usage() {
  SCRIPT_NAME=$(basename "$0")
  echo "Usage: $SCRIPT_NAME <aws-profile> <log-group> <from> <to> [<output-dir>]"
  echo "Example: $SCRIPT_NAME"
  echo "Parameters:"
  echo "  aws-profile  AWS profile to use"
  echo "  log-group    Name of the log group to download"
  echo "  from         Timestamp (Unix epoch in milliseconds) of the date and time from which download the logs"
  echo "  to           Timestamp (Unix epoch in milliseconds) of the date and time up to which download the logs"
  echo "  output-dir   Directory where store downloaded logs"
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

OUTPUT_DIR=$5
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR=.
fi

export AWS_PAGER="" # Disable pagination
export AWS_REGION=me-south-1

echo "AWS profile to use: $AWS_PROFILE"
echo "Log group to download: $LOG_GROUP"
echo "From: $(date -r $(($FROM / 1000))) ($(date -u -r $(($FROM / 1000))))"
echo "To: $(date -r $(($TO / 1000))) ($(date -u -r $(($TO / 1000))))"
echo "Output directory: $OUTPUT_DIR"

mkdir -p $OUTPUT_DIR

LOG_STREAMS=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP")
while IFS= read -r log_stream_name; do
  echo "Processing log stream: $log_stream_name"

    LOG_FILE="${OUTPUT_DIR}/${log_stream_name}_${FROM}_${TO}.log"
    echo -n "" > "$LOG_FILE"

    LAST_TOKEN="last"
    CURRENT_TOKEN=""
    while [ "$LAST_TOKEN" != "$CURRENT_TOKEN" ]; do
      LAST_TOKEN=$CURRENT_TOKEN
      printf "\tProcessing token: %s\n" "$CURRENT_TOKEN"
      if [ -n "$CURRENT_TOKEN" ]; then
        CURRENT_TOKEN="--next-token $CURRENT_TOKEN"
      fi
      LOGS=$(aws logs get-log-events $CURRENT_TOKEN --log-group-name "$LOG_GROUP" --log-stream-name "$log_stream_name" --start-time "$FROM" --end-time "$TO")
      CURRENT_TOKEN=$(echo "$LOGS" | jq -r '.nextForwardToken')
      echo "$LOGS" | jq -c -r '.events[] | .message' >> "$LOG_FILE"
    done

done < <(echo "$LOG_STREAMS" | jq -c -r '.logStreams[].logStreamName')
