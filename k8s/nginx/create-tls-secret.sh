#!/bin/bash
# Este script cria o Kubernetes Secret com o certificado TLS
# Corre DEPOIS do terraform apply e do kubectl config

kubectl create secret tls nginx-tls \
  --cert=nginx/ssl/tls.crt \
  --key=nginx/ssl/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret nginx-tls criado com sucesso!"
