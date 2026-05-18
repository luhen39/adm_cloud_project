#!/bin/bash
# Cria os 3 buckets e service account dedicado no MinIO
# Corre DEPOIS do kubectl apply

# Aguardar MinIO estar pronto
kubectl wait --for=condition=ready pod -l app=minio --timeout=120s

# Port-forward temporário
kubectl port-forward svc/minio-service 9000:9000 &
PF_PID=$!
sleep 3

# Criar buckets
docker run --rm --network host minio/mc:latest \
  alias set local http://localhost:9000 \
  $(kubectl get secret minio-secrets -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d) \
  $(kubectl get secret minio-secrets -o jsonpath='{.data.MINIO_ROOT_PASSWORD}' | base64 -d)

docker run --rm --network host minio/mc:latest mb local/files
docker run --rm --network host minio/mc:latest mb local/thumbnails
docker run --rm --network host minio/mc:latest mb local/tmp

# Criar service account dedicado com politica minima
API_USER=$(kubectl get secret api-secrets -o jsonpath='{.data.MINIO_ACCESS_KEY}' | base64 -d)
API_PASSWORD=$(kubectl get secret api-secrets -o jsonpath='{.data.MINIO_SECRET_KEY}' | base64 -d)

docker run --rm --network host minio/mc:latest \
  admin user add local "$API_USER" \
  "$API_PASSWORD"

# Criar política mínima (só acesso aos buckets necessários)
docker run --rm --network host minio/mc:latest \
  admin policy create local api-policy /dev/stdin << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::files/*",
        "arn:aws:s3:::files",
        "arn:aws:s3:::thumbnails/*",
        "arn:aws:s3:::thumbnails",
        "arn:aws:s3:::tmp/*",
        "arn:aws:s3:::tmp"
      ]
    }
  ]
}
POLICY

# Associar política ao utilizador
docker run --rm --network host minio/mc:latest \
  admin policy attach local api-policy --user "$API_USER"

kill $PF_PID
echo "Buckets e service account criados com sucesso!"
