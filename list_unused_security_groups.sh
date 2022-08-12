#!/usr/bin/env bash

print_usage() {
  SCRIPT_NAME=$(basename "$0")
  echo "Usage: $SCRIPT_NAME <aws-profile> <aws-region>"
  echo "Example: $SCRIPT_NAME my-profile us-east-1"
  exit "$1"
}

export AWS_PROFILE=$1
if [ -z "$AWS_PROFILE" ]; then
  1>&2 echo "[ERROR] Please specify the AWS profile name as first argument"
  print_usage 1
fi

export AWS_REGION=$2
if [ -z "$AWS_REGION" ]; then
  1>&2 echo "[ERROR] Please specify the AWS region as second argument"
  print_usage 2
fi

export AWS_PAGER="" # Disable pagination

SG_IDS=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].GroupId'  --output text | tr '\t' '\n'| sort)
SG_IDS_EC2=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' --output text)
SG_IDS_SG=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].IpPermissions[*].UserIdGroupPairs[*].GroupId'  --output text)
SG_IDS_NI=$(aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].Groups[*].GroupId'  --output text)
SG_USED=$(printf "$SG_IDS_EC2\t$SG_IDS_SG\t$SG_IDS_NI\t" | tr '\t' '\n' | sort | uniq)
comm -23  <(printf "$SG_IDS") <(printf "$SG_USED")
