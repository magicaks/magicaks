#!/bin/bash

GHUSER=$1
REPO=$2
PAT=$3
NS=$4

now=$(date +'%m-%d-%Y')

FLUXID=`fluxctl identity --k8s-fwd-ns ${NS}`
echo $FLUXID

curl -XPOST -H "Content-Type: application/json" \
               -H "Authorization: token ${PAT}" \
               -d "{ \"title\": \"magicaks-${now}\",\"key\": \"${FLUXID}\" }" \
               https://api.github.com/repos/${GHUSER}/${REPO}/keys

sleep 60
# Force first sync of repo
fluxctl sync --k8s-fwd-ns $NS
