import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException
from config import settings

# Cliente interno — usado para todas as operações normais (upload, download, etc.)
client = boto3.client(
    "s3",
    endpoint_url=f"{'https' if settings.minio_secure else 'http'}://{settings.minio_endpoint}",
    aws_access_key_id=settings.minio_access_key,
    aws_secret_access_key=settings.minio_secret_key,
    config=Config(
        signature_version="s3v4",
        s3={"addressing_style": "path"}
    ),
    region_name="us-east-1"
)

# Cliente público — usado apenas para gerar presigned URLs acessíveis externamente
presign_client = boto3.client(
    "s3",
    endpoint_url=f"{'https' if settings.minio_secure else 'http'}://{settings.minio_public_endpoint}",
    aws_access_key_id=settings.minio_access_key,
    aws_secret_access_key=settings.minio_secret_key,
    config=Config(
        signature_version="s3v4",
        s3={"addressing_style": "path"}
    ),
    region_name="us-east-1"
)

BUCKETS = ["files", "thumbnails", "tmp"]


def init_buckets():
    for bucket in BUCKETS:
        try:
            client.head_bucket(Bucket=bucket)
        except ClientError:
            client.create_bucket(Bucket=bucket)


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
        extra_args = {"ContentType": content_type}
        if metadata:
            extra_args["Metadata"] = {k: str(v) for k, v in metadata.items()}
        client.upload_fileobj(
            file_data,
            settings.minio_bucket,
            object_name,
            ExtraArgs=extra_args
        )
        return object_name
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Erro no upload: {str(e)}")


def download_file(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        response = client.get_object(Bucket=settings.minio_bucket, Key=object_name)
        return response["Body"]
    except ClientError as e:
        if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
            raise HTTPException(status_code=404, detail="Ficheiro não encontrado")
        raise HTTPException(status_code=500, detail=f"Erro no download: {str(e)}")


def delete_file(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        client.delete_object(Bucket=settings.minio_bucket, Key=object_name)
    except ClientError as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")


def list_files(username: str):
    try:
        response = client.list_objects_v2(
            Bucket=settings.minio_bucket,
            Prefix=f"{username}/"
        )
        contents = response.get("Contents", [])
        return [obj["Key"].split("/")[-1] for obj in contents]
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar ficheiros: {str(e)}")


def get_file_meta(username: str, file_id: str):
    try:
        object_name = f"{username}/{file_id}"
        response = client.head_object(Bucket=settings.minio_bucket, Key=object_name)
        metadata = response.get("Metadata", {})
        name = metadata.get("original-filename") or file_id
        return {
            "file_id": file_id,
            "name": name,
            "size": response["ContentLength"],
            "content_type": response["ContentType"],
            "upload_timestamp": response["LastModified"].isoformat()
        }
    except ClientError as e:
        if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
            raise HTTPException(status_code=404, detail="Ficheiro não encontrado")
        raise HTTPException(status_code=500, detail=f"Erro ao obter metadata: {str(e)}")


def generate_presigned_url(username: str, file_id: str, ttl_seconds: int) -> str:
    try:
        object_name = f"{username}/{file_id}"
        url = presign_client.generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.minio_bucket, "Key": object_name},
            ExpiresIn=ttl_seconds
        )
        return url
    except ClientError as e:
        raise HTTPException(status_code=404, detail=f"Ficheiro não encontrado: {str(e)}")


def get_user_quota_used(username: str) -> int:
    try:
        response = client.list_objects_v2(
            Bucket=settings.minio_bucket,
            Prefix=f"{username}/"
        )
        contents = response.get("Contents", [])
        return sum(obj.get("Size", 0) for obj in contents)
    except ClientError:
        return 0