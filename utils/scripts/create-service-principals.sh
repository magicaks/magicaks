#!/bin/bash

SUBSCRIPTION_ID=$1

if [ -z "$SUBSCRIPTION_ID" ]
then
    echo "This script creates service principals required by MagicAKS"
    echo
    echo "Usage: $0 <Azure subscription ID>"
    exit 1
fi

# Create service principal Terraform will use for deploying resources
SERVICE_PRINCIPAL_DETAILS=$(az ad sp create-for-rbac --role "Contributor" --name "http://magicaks-terraform" --scopes="/subscriptions/$SUBSCRIPTION_ID")

TERRAFORM_SP_APP_ID=$(jq --raw-output '.appId' <<< $SERVICE_PRINCIPAL_DETAILS)
TERRAFORM_SP_PASSWORD=$(jq --raw-output '.password' <<< $SERVICE_PRINCIPAL_DETAILS)

OBJECT_ID=$(az ad sp show --id $TERRAFORM_SP_APP_ID | jq --raw-output '.objectId')
RETRIES="0"

while [ "${#OBJECT_ID}" -lt 36 ]
do
    echo "Failed to obtain object ID, retrying $[$RETRIES+1]/5..."
    sleep 10
    OBJECT_ID=$(az ad sp show --id $TERRAFORM_SP_APP_ID | jq --raw-output '.objectId')
    RETRIES=$[$RETRIES+1]

    if [ $RETRIES -gt 4 ]
    then
        echo "Failed"
        exit 1
    fi
done

az role assignment create --assignee-object-id $OBJECT_ID --role "Resource Policy Contributor" # Needed to assign Azure policy to cluster

# Create service principal (magicaks-grafana) Grafana will use for talking to Log Analytics backend
SERVICE_PRINCIPAL_DETAILS=$(az ad sp create-for-rbac --role "Monitoring Reader" --name "http://magicaks-grafana")

GRAFANA_SP_APP_ID=$(jq --raw-output '.appId' <<< $SERVICE_PRINCIPAL_DETAILS)
GRAFANA_SP_PASSWORD=$(jq --raw-output '.password' <<< $SERVICE_PRINCIPAL_DETAILS)

echo
echo "Terraform service principal app ID: $TERRAFORM_SP_APP_ID"
echo "Terraform service principal password: $TERRAFORM_SP_PASSWORD"
echo
echo "Grafana service principal app ID: $GRAFANA_SP_APP_ID"
echo "Grafana service principal password: $GRAFANA_SP_PASSWORD"
echo
