## Install NGINX Ingress controller

```
helm install stable/nginx-ingress  --tiller-namespace dev --namespace dev --set controller.replicaCount=3 --set controller.service.loadBalancerIP=40.114.203.251 --set controller.scope.enabled=true --set controller.scope.namespace=dev --tls-verify
```