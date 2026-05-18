#!/bin/bash
# Cria os Kubernetes Secrets para a API
# Corre DEPOIS do terraform apply

read -p "MinIO API User: " MINIO_USER
read -s -p "MinIO API Password: " MINIO_PASSWORD
echo
read -s -p "JWT Secret: " JWT_SECRET
echo
read -s -p "Auth users (user:pass,user2:pass2): " AUTH_USERS
echo

kubectl create secret generic api-secrets \
  --from-literal=MINIO_ACCESS_KEY=$MINIO_USER \
  --from-literal=MINIO_SECRET_KEY=$MINIO_PASSWORD \
  --from-literal=JWT_SECRET=$JWT_SECRET \
  --from-literal=AUTH_USERS=$AUTH_USERS \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret api-secrets criado com sucesso!"
