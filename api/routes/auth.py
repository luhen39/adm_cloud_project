from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel
from services.auth import create_token, verify_token
import secrets

router = APIRouter()
security = HTTPBasic()

# Utilizadores de exemplo (em produção usar base de dados)
USERS = {
    "admin": "admin123",
    "user1": "password1"
}

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    # Verificar credenciais
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
    
    # Gerar JWT
    token = create_token({"sub": request.username})
    return TokenResponse(access_token=token)

@router.get("/validate")
async def validate(token: str = Depends(verify_token)):
    return {"username": token}
