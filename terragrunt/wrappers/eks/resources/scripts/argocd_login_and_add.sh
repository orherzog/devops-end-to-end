#!/bin/bash

# Arguments
CLUSTER_URL=$1
USERNAME=$2
PASSWORD=$3
CLUSTER_ARN=$4
CLUSTER_NAME=$5

# Check for required arguments
if [ -z "$CLUSTER_URL" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$CLUSTER_ARN" ] || [ -z "$CLUSTER_NAME" ]; then
  echo "{\"status\": \"error\", \"message\": \"Missing required arguments\"}"
  exit 1
fi

# Login to ArgoCD
if argocd login $CLUSTER_URL --username $USERNAME --password $PASSWORD --insecure; then
  echo "Logged in to ArgoCD successfully."
else
  echo "{\"status\": \"login_failed\", \"message\": \"Failed to log in to ArgoCD\"}"
  exit 1
fi

# Add the cluster
if argocd cluster add $CLUSTER_ARN --name $CLUSTER_NAME; then
  echo "{\"status\": \"success\", \"message\": \"Cluster $CLUSTER_NAME added successfully\"}"
else
  echo "{\"status\": \"add_failed\", \"message\": \"Failed to add cluster $CLUSTER_NAME\"}"
  exit 1
fi
