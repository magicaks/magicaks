#!/bin/bash

secret_name=$1
kvid=$2
readarray -d / -t splitNoIFS<<< "$kvid"
kv=${splitNoIFS[-1]}
namespace=$3
cat <<EOF | kubectl apply -f -
apiVersion: spv.no/v1
kind: AzureKeyVaultSecret
metadata:
  name: $secret_name
  namespace: $namespace
spec:
  vault:
    name: $kv # name of key vault
    object:
      type: secret # object type
      name: $secret_name # name of the object
  output:
    secret:
      name: $secret_name
      dataKey: $secret_name
EOF