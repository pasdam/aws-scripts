#!/usr/bin/env bash

print_usage() {
  SCRIPT_NAME=$(basename "$0")
  echo "Usage: $SCRIPT_NAME <aws-profile> <env_name>"
  echo "Example: $SCRIPT_NAME my-profile production"
  echo "This script assume the ssh key for the specified environment to be: ~/.ssh/id_rsa_<env_name>, i.e. ~/.ssh/id_rsa_production"
  exit "$1"
}

export AWS_PROFILE=$1
if [ -z "$AWS_PROFILE" ]; then
  1>&2 echo "Please specify the AWS profile name as first argument"
  print_usage 1
fi

ENV_NAME=$2
if [ -z "$ENV_NAME" ]; then
  1>&2 echo "Please specify the environment name as second argument"
  print_usage 2
fi

export AWS_PAGER="" # Disable pagination
export AWS_REGION=me-south-1

INSTANCES=$(aws ec2 describe-instances --filters Name=instance-state-code,Values=16)
INSTANCES_SORTED=$(echo "$INSTANCES" | jq '[.Reservations[].Instances[] | {Name: ((.Tags[] | select(.Key == "Name")).Value ? // .InstanceId), InstanceId:.InstanceId, Tags: .Tags}] | sort_by(.Name)')

while IFS= read -r id; do
  INSTANCE=$(echo "$INSTANCES" | jq '.Reservations[].Instances[] | select(.InstanceId == "'"$id"'")')
  HOST=$(echo "$INSTANCE" | jq -r '(.Tags[] | select(.Key == "Name")).Value ? // .InstanceId')
  IP=$(echo "$INSTANCE" | jq -r '.PrivateIpAddress')
  OS=$(echo "$INSTANCE" | jq -r '.Tags[] | select(.Key == "OSDistro").Value')
  USER=ec2-user
  if [ "$OS" = "Ubuntu" ]; then
    USER=ubuntu
  fi
  printf "Host %s\n" "$HOST"
  printf "    HostName %s\n" "$IP"
  printf "    AddKeysToAgent yes\n"
  printf "    UseKeychain yes\n"
  printf "    User %s\n" "$USER"
  printf "    IdentitiesOnly yes\n"
  printf "    IdentityFile ~/.ssh/id_rsa_%s\n" "$ENV_NAME"
  printf "\n"
done < <(echo "$INSTANCES_SORTED" | jq -c -r '.[] | .InstanceId')
