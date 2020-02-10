#!/bin/bash
eg_domain_name=`echo $1 | sed -e 's|^[^/]*//||' -e 's|/.*$||'`

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: eventgrid
  namespace: default
spec:
  type: ExternalName
  externalName: ${eg_domain_name}
EOF