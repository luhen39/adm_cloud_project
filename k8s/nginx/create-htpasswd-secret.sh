#!/bin/bash
kubectl create secret generic nginx-htpasswd \
  --from-file=.htpasswd=nginx/auth/.htpasswd \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret nginx-htpasswd criado com sucesso!"
