#!/bin/bash

CLUSTER_NAME=$1

if kubectl config get-clusters | grep -q "$CLUSTER_NAME"; then
  echo "{\"status\": \"found\", \"message\": \"Cluster $CLUSTER_NAME was found in kubeconfig\"}"
else
  echo "{\"status\": \"not_found\", \"message\": \"Cluster $CLUSTER_NAME not found in kubeconfig\"}"
  exit 1
fi
