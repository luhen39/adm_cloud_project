import secrets
from fastapi import APIRouter, HTTPException, status
from services.auth import create_token, verify_token
from fastapi import Depends
from models import LoginRequest, TokenResponse

router = APIRouter()

# Utilizadores de exemplo (em produção usar base de dados)
USERS = {
    "admin": "admin123",
    "user1": "password1"
}

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    if request.username not in USERS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas"
        )

    if not secrets.compare_digest(USERS[request.username], request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas"
        )

    token = create_token({"sub": request.username})
    return TokenResponse(access_token=token)

@router.get("/validate")
async def validate(token: str = Depends(verify_token)):
    return {"username": token}
