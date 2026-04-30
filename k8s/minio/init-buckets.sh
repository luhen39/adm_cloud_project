#!/bin/bash
# Cria os 3 buckets necessários no MinIO
# Corre DEPOIS do kubectl apply

# Aguardar MinIO estar pronto
kubectl wait --for=condition=ready pod -l app=minio --timeout=120s

# Port-forward temporário
kubectl port-forward svc/minio-service 9000:9000 &
PF_PID=$!
sleep 3

# Criar buckets via mc (MinIO Client)
docker run --rm --network host \
  minio/mc:latest \
  alias set local http://localhost:9000 changeme changeme

docker run --rm --network host \
  minio/mc:latest \
  mb local/files local/thumbnails local/tmp

# Criar service account com política mínima
docker run --rm --network host \
  minio/mc:latest \
  admin user add local api-user changeme-api

docker run --rm --network host \
  minio/mc:latest \
  admin policy attach local readwrite --user api-user

kill $PF_PID
echo "Buckets e service account criados com sucesso!"
