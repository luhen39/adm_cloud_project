import secrets
from fastapi import APIRouter, HTTPException, status, Header
from services.auth import create_token, get_username_from_authorization
from models import LoginRequest, TokenResponse
from config import settings

router = APIRouter()

def get_users() -> dict:
    users = {}
    raw = settings.auth_users or ""
    for item in raw.split(","):
        item = item.strip()
        if not item or ":" not in item:
            continue
        username, password = item.split(":", 1)
        users[username] = password
    return users

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    users = get_users()
    if request.username not in users:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas"
        )

    if not secrets.compare_digest(users[request.username], request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas"
        )

    token = create_token({"sub": request.username})
    return TokenResponse(access_token=token)

@router.get("/validate", include_in_schema=False)
async def validate(authorization: str | None = Header(None)):
    get_username_from_authorization(authorization)
    return {"status": "ok"}