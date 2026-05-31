#!/bin/bash
kubectl create secret tls nginx-tls \
  --cert=nginx/ssl/tls.crt \
  --key=nginx/ssl/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret nginx-tls criado com sucesso!"
