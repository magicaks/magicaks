#!/bin/bash

secret_name=$1
kv=$2
cat <<EOF | kubectl apply -f -
apiVersion: spv.no/v1alpha1
kind: AzureKeyVaultSecret
metadata:
  name: $secret_name
  namespace: default
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