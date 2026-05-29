import base64
from datetime import datetime, timedelta
from fastapi import HTTPException, status
from jose import jwt, JWTError
from config import settings
import secrets

def get_users() -> dict:
    """Carrega a lista de utilizadores do settings"""
    users = {}
    raw = settings.auth_users or ""
    for item in raw.split(","):
        item = item.strip()
        if not item or ":" not in item:
            continue
        username, password = item.split(":", 1)
        users[username] = password
    return users


def create_token(data: dict) -> str:
    payload = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expiry_minutes)
    payload.update({"exp": expire})
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm]
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido ou expirado"
        )


def get_username_from_authorization(authorization: str) -> str:
    """Extrai username de um header Authorization: Bearer <token>"""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header invalido"
        )
    payload = decode_token(token)
    username = payload.get("sub")
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sem utilizador"
        )
    return username


def decode_basic_auth(authorization: str) -> str:
    try:
        _, _, encoded = authorization.partition(" ")
        decoded = base64.b64decode(encoded).decode("utf-8")
        username, _, password = decoded.partition(":")
        
        # Validar contra a lista de utilizadores
        users = get_users()
        if username not in users or not secrets.compare_digest(users[username], password):
            raise HTTPException(status_code=401, detail="Credenciais inválidas")
        
        return username
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Basic Auth inválido")


def get_username_from_headers(
    authorization: str | None,
    x_authenticated_user: str | None
) -> str:
    """
    Tenta extrair o username por ordem de prioridade:
    1. Authorization: Bearer <jwt>
    2. Authorization: Basic <base64>
    3. Header X-Authenticated-User (injetado por proxy/ingress)
    """
    if authorization:
        scheme, _, _ = authorization.partition(" ")
        if scheme.lower() == "bearer":
            return get_username_from_authorization(authorization)
        if scheme.lower() == "basic":
            return decode_basic_auth(authorization)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Esquema de autenticação invalido. Use Bearer ou Basic."
        )

    if x_authenticated_user:
        return x_authenticated_user

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated"
    )