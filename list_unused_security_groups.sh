#!/usr/bin/env bash

if [ -z "$AWS_PROFILE" ]; then
  export AWS_PROFILE=$1
  if [ -z "$AWS_PROFILE" ]; then
    1>&2 echo "Please specify the AWS profile name as first argument"
  fi
fi

if [ -z "$AWS_REGION" ]; then
  export AWS_REGION=$2
  if [ -z "$AWS_REGION" ]; then
    1>&2 echo "Please specify the AWS region as second argument"
  fi
fi

export AWS_PAGER="" # Disable pagination

SG_IDS=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].GroupId'  --output text | tr '\t' '\n'| sort)
SG_IDS_EC2=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' --output text)
SG_IDS_SG=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].IpPermissions[*].UserIdGroupPairs[*].GroupId'  --output text)
SG_IDS_NI=$(aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].Groups[*].GroupId'  --output text)
SG_USED=$(printf "$SG_IDS_EC2\t$SG_IDS_SG\t$SG_IDS_NI\t" | tr '\t' '\n' | sort | uniq)
comm -23  <(printf "$SG_IDS") <(printf "$SG_USED")
