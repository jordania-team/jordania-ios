# backend_mock.py
# Mock local do backend Jordania para a spike de autenticacao.
#
# Como rodar:
#   pip3 install fastapi uvicorn
#   uvicorn backend_mock:app --reload
#
# Endpoint:
#   POST http://localhost:8000/auth/login
#   Body: { "provider": "apple" | "google", "identityToken": "<token>" }
#
# IMPORTANTE: Este arquivo e apenas para a spike.
# Nao commitar tokens reais. Nao usar em producao.

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, model_validator
from typing import Optional
import uuid
import time

app = FastAPI(title="Jordania Auth Mock", version="0.1.1-spike")

VALID_PROVIDERS = {"apple", "google"}


class LoginRequest(BaseModel):
    provider: str
    # Aceita tanto camelCase (iOS) quanto snake_case para compatibilidade futura.
    identityToken: Optional[str] = Field(default=None)
    identity_token: Optional[str] = Field(default=None)

    @model_validator(mode="after")
    def resolve_token(self) -> "LoginRequest":
        token = self.identityToken or self.identity_token
        if not token:
            raise ValueError("identityToken nao pode ser vazio.")
        self.identityToken = token
        return self


class LoginResponse(BaseModel):
    access_token: str
    user_id: str
    name: Optional[str]
    email: Optional[str]


@app.post("/auth/login", response_model=LoginResponse)
def login(body: LoginRequest) -> LoginResponse:
    if body.provider not in VALID_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Provider invalido: {body.provider}")

    mock_jwt = f"mock.jwt.{body.provider}.{int(time.time())}.{uuid.uuid4().hex[:8]}"

    return LoginResponse(
        access_token=mock_jwt,
        user_id=str(uuid.uuid4()),
        name="Mock User Jordania",
        email=f"mock.{body.provider}@jordania.app",
    )


@app.get("/health")
def health():
    return {"status": "ok", "mock": True}
