#!/bin/bash
# Cria o Secret do MinIO (root creds) sem guardar valores no repo

read -p "MinIO Root User: " MINIO_ROOT_USER
read -s -p "MinIO Root Password: " MINIO_ROOT_PASSWORD
echo

kubectl create secret generic minio-secrets \
  --from-literal=MINIO_ROOT_USER=$MINIO_ROOT_USER \
  --from-literal=MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret minio-secrets criado com sucesso!"
