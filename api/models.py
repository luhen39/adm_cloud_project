from pydantic import BaseModel
from typing import Optional

class ProblemDetail(BaseModel):
    type: str = "about:blank"
    title: str
    status: int
    detail: str
    instance: Optional[str] = None

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class ShareRequest(BaseModel):
    ttl_seconds: int = 3600

class ShareResponse(BaseModel):
    url: str
    ttl_seconds: int
