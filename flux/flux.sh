#!/bin/bash
# $1 = Resource group name
# $2 = Cluster name

# Get kubecredentials
az aks get-credentials -g $1 -n $2 --overwrite

# Set the right context
kubectl config set-context $2

# Install Flux
kubectl create ns flux

GHUSER=$3
fluxctl install \
--git-user=${GHUSER} \
--git-email=${GHUSER}@users.noreply.github.com \
--git-url=git@github.com:sachinkundu/k8smanifests.git \
--git-path=dev \
--namespace=flux | kubectl apply -f -

kubectl -n flux rollout status deployment/flux -w

# Install ssh key into github

FLUXID=`fluxctl identity --k8s-fwd-ns flux`
echo $FLUXID