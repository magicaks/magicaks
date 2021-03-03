#!/bin/bash

# This script creates a managed identity for the cluster and stores it in the shared resource group so that it can be reused
# even if the cluster is destroyed or re-created

SHARED_RESOURCE_GROUP=$1

if [ -z "$SHARED_RESOURCE_GROUP" ]
then
    echo "MagicAKS managed identity script"
    echo
    echo "Usage: $0 <shared resource group name>"
    exit 1
fi

az identity create --name magicaksmsi --resource-group $SHARED_RESOURCE_GROUP
eval MSI_CLIENT_ID=$(az identity show -n magicaksmsi -g $SHARED_RESOURCE_GROUP -o json | jq -r ".clientId")
eval MSI_RESOURCE_ID=$(az identity show -n magicaksmsi -g $SHARED_RESOURCE_GROUP -o json | jq -r ".id")
az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID -g $SHARED_RESOURCE_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $MSI_CLIENT_ID -g $SHARED_RESOURCE_GROUP
echo "Managed Identity Client ID: $MSI_CLIENT_ID"
echo "Managed Identity Resource ID: $MSI_RESOURCE_ID"
