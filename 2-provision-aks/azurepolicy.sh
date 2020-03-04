#!/bin/bash

cluster_name=$1
rg_name=$2

# Provider register: Register the Azure Kubernetes Services provider
cs_registered=`az provider show -n Microsoft.ContainerService -o json | jq .registrationState`
if test $cs_registered != \"Registered\"
then 
    az provider register --namespace Microsoft.ContainerService
else 
    echo "provider Microsoft.ContainerService already registered"
fi

# Provider register: Register the Azure Policy provider
ap_registered=`az provider show -n Microsoft.PolicyInsights -o json | jq .registrationState`
if test $ap_registered != \"Registered\"
then 
    az provider register --namespace Microsoft.PolicyInsights
else 
    echo "provider Microsoft.PolicyInsights already registered"
fi

# Feature register: enables installing the add-on
feature_registerd=`az feature show --namespace Microsoft.ContainerService --name AKS-AzurePolicyAutoApprove | jq .properties.state`
if test $feature_registerd != \"Registered\"
then 
    az feature register --namespace Microsoft.ContainerService --name AKS-AzurePolicyAutoApprove
else
    echo "Microsoft.ContainerService AKS-AzurePolicyAutoApprove already registered"
fi

while test $feature_registerd != \"Registered\"
do 
    sleep 10; 
    feature_registerd=`az feature show --namespace Microsoft.ContainerService --name AKS-AzurePolicyAutoApprove | jq .properties.state`
done

# Once the above shows 'Registered' run the following to propagate the update
az provider register -n Microsoft.ContainerService

feature_registerd=`az feature show --namespace Microsoft.PolicyInsights --name AKS-DataplaneAutoApprove | jq .properties.state`
if test $feature_registerd != \"Registered\"
then 
    az feature register --namespace Microsoft.PolicyInsights --name AKS-DataplaneAutoApprove
else
    echo "Microsoft.PolicyInsights AKS-DataplaneAutoApprove already registered"
fi

while test $feature_registerd != \"Registered\"
do 
    sleep 10; 
    feature_registerd=`az feature show --namespace Microsoft.PolicyInsights --name AKS-DataplaneAutoApprove | jq .properties.state`
done

# Once the above shows 'Registered' run the following to propagate the update
az provider register -n Microsoft.PolicyInsights

az extension add --name aks-preview
az aks enable-addons --addons azure-policy --name $cluster_name --resource-group $rg_name