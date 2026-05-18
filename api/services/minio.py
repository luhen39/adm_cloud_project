from minio import Minio
from minio.error import S3Error
from datetime import timedelta
from fastapi import HTTPException
from config import settings

client = Minio(
    settings.minio_endpoint,
    access_key=settings.minio_access_key,
    secret_key=settings.minio_secret_key,
    secure=settings.minio_secure
)

BUCKETS = ["files", "thumbnails", "tmp"]

def init_buckets():
    for bucket in BUCKETS:
        if not client.bucket_exists(bucket):
            client.make_bucket(bucket)

def upload_file(
    username: str,
    file_id: str,
    file_data,
    size: int,
    content_type: str,
    metadata: dict | None = None
):
    try:
        object_name = f"{username}/{file_id}"
        client.put_object(
            settings.minio_bucket,
            object_name,
            file_data,
            size,
            content_type=content_type,
            metadata=metadata
        )
        return object_name
    except S3Error as e:
        raise HTTPException(status_code=500, detail=f"Erro no upload: {str(e)}")

def download_file(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        return client.get_object(settings.minio_bucket, object_name)
    except S3Error as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")

def delete_file(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        client.remove_object(settings.minio_bucket, object_name)
    except S3Error as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")

def list_files(username: str):
    try:
        objects = client.list_objects(settings.minio_bucket, prefix=f"{username}/")
        return [obj.object_name.split("/")[-1] for obj in objects]
    except S3Error as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar ficheiros: {str(e)}")

def get_file_meta(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        stat = client.stat_object(settings.minio_bucket, object_name)
        metadata = stat.metadata or {}
        name = (
            metadata.get("original-filename")
            or metadata.get("x-amz-meta-original-filename")
            or file_id
        )
        return {
            "file_id": file_id,
            "name": name,
            "size": stat.size,
            "content_type": stat.content_type,
            "upload_timestamp": stat.last_modified.isoformat()
        }
    except S3Error as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")

def generate_presigned_url(username: str, file_id: str, ttl_seconds: int) -> str:
    try:
        object_name = f"{username}/{file_id}"
        url = client.presigned_get_object(
            settings.minio_bucket,
            object_name,
            expires=timedelta(seconds=ttl_seconds)
        )
        return url
    except S3Error as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")

def get_user_quota_used(username: str) -> int:
    try:
        objects = client.list_objects(settings.minio_bucket, prefix=f"{username}/")
        total = sum(obj.size for obj in objects if obj.size)
        return total
    except S3Error:
        return 0
