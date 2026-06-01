# backend_mock.py
# Mock local do backend Jordania para a spike de autenticacao.
#
# Como rodar:
#   pip install fastapi uvicorn
#   uvicorn backend_mock:app --reload
#
# Endpoint:
#   POST http://localhost:8000/auth/login
#   Body: { "provider": "apple" | "google", "identity_token": "<token>" }
#
# IMPORTANTE: Este arquivo e apenas para a spike.
# Nao commitar tokens reais. Nao usar em producao.

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uuid
import time

app = FastAPI(title="Jordania Auth Mock", version="0.1.0-spike")

VALID_PROVIDERS = {"apple", "google"}


class LoginRequest(BaseModel):
    provider: str
    identity_token: str


class LoginResponse(BaseModel):
    access_token: str
    user_id: str
    name: str | None
    email: str | None


@app.post("/auth/login", response_model=LoginResponse)
def login(body: LoginRequest) -> LoginResponse:
    if body.provider not in VALID_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Provider invalido: {body.provider}")

    if not body.identity_token:
        raise HTTPException(status_code=400, detail="identity_token nao pode ser vazio.")

    # Simula um JWT real com timestamp para facilitar debug.
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
