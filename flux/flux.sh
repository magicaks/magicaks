#!/bin/bash
RGNAME=$1
CLUSTERNAME=$2
GHUSER=$3
REPO=$4
PAT=$5

# Get kubecredentials
az aks get-credentials -g ${RGNAME} -n ${CLUSTERNAME} --admin --overwrite

# Set the right context
kubectl config set-context ${CLUSTERNAME}

# Install Flux
kubectl create ns flux

fluxctl install \
--git-user=${GHUSER} \
--git-email=${GHUSER}@users.noreply.github.com \
--git-url=git@github.com:${GHUSER}/${REPO}.git \
--git-path=dev \
--registry-disable-scanning \
--namespace=flux | kubectl apply -f -

kubectl -n flux rollout status deployment/flux -w

# Install ssh key into github

FLUXID=`fluxctl identity --k8s-fwd-ns flux`
echo $FLUXID

curl -XPOST -H "Content-Type: application/json" \
               -H "Authorization: token ${PAT}" \
               -d "{ \"title\": \"magicaks\",\"key\": \"${FLUXID}\" }" \
               https://api.github.com/repos/${GHUSER}/${REPO}/keys