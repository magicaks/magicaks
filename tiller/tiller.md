## Steps required to get secure Helm installation

These steps will ensure that helm is installed in dev namespace and can only install in that namespace.

We also make sure that the connection with helm tiller happens over TLS.

```
kubectl create namespace dev
```

```
kubectl create serviceaccount tiller --namespace dev
```

```
kubectl apply -f role_tiller.yaml
```

```
kubectl apply -f role_binding_tiller.yaml
```

```
helm init --override 'spec.template.spec.containers[0].command'='{/tiller,--storage=secret}' --service-account tiller --tiller-namespace dev --tiller-tls --tiller-tls-cert ./tiller.cert.pem --tiller-tls-key ./tiller.key.pem --tiller-tls-verify --tls-ca-cert ca.cert.pem
```

```
cp ca.cert.pem $(helm home)/ca.pem
cp helm.cert.pem $(helm home)/cert.pem
cp helm.key.pem $(helm home)/key.pem
```

```
helm ls --tiller-namespace dev --tls
```