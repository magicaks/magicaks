#!/bin/bash
RGNAME=$1
CLUSTERNAME=$2

# Get cluster credentials
az aks get-credentials -g ${RGNAME} -n ${CLUSTERNAME} --admin --overwrite

# Set the right context
kubectl config set-context ${CLUSTERNAME}