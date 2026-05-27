from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # MinIO
    minio_endpoint: str = "minio-service:9000"
    minio_access_key: str = "replace-me"
    minio_secret_key: str = "replace-me"
    minio_secure: bool = False
    minio_bucket: str = "files"
    minio_public_endpoint: str = "207.175.30.184:9000"

    # JWT
    jwt_secret: str = "replace-me"
    jwt_algorithm: str = "HS256"
    jwt_expiry_minutes: int = 60

    # Credenciais de login: "user:pass,user2:pass2"
    auth_users: str = ""

    # Quota por utilizador (bytes)
    user_quota_bytes: int = 1073741824  # 1GB

    class Config:
        env_file = ".env"
        # Permite ler variáveis de ambiente em maiúsculas
        case_sensitive = False

settings = Settings()
