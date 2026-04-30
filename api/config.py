from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # MinIO
    minio_endpoint: str = "minio-service:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_secure: bool = False
    minio_bucket: str = "files"

    # JWT
    jwt_secret: str = "changeme"
    jwt_algorithm: str = "HS256"
    jwt_expiry_minutes: int = 60

    # Quota por utilizador (bytes)
    user_quota_bytes: int = 1073741824  # 1GB

    class Config:
        env_file = ".env"

settings = Settings()
