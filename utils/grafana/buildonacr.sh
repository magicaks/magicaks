#!/usr/bin/env bash
acr=$1
repository=$2

az acr repository show -n $acr --repository $2 > /dev/null 2>&1

if [ $? -ne 0 ]; then
    cd utils/grafana
    az acr build -t $acr.azurecr.io/$repository -r $acr .
fi
exit $retVal