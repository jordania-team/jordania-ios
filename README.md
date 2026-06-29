# TarefasPOC — Debug Access + Refresh Token

POC iOS em SwiftUI para validar o fluxo real do backend publicado em:

```text
https://api.redepets.xyz
```

Esta POC prioriza observabilidade. Depois do login Apple/Google, a tela autenticada vira um dashboard com sessão, claims do JWT, refresh token mascarado, chamadas protegidas, retries automáticos e testes negativos.

## O Que Ela Testa

- `POST /auth/login` com Apple ou Google.
- Persistência separada de sessão (`current-session`) e credenciais (`session-credentials`) no Keychain.
- Access token JWT interno e refresh token opaco.
- Refresh preventivo quando o access token está expirado localmente.
- Refresh automático quando uma request protegida recebe `401`.
- Retry único da request original após refresh.
- `POST /auth/logout` no logout remoto, seguido de limpeza local.
- `GET /users/me`.
- `GET /api/tutors/me`.
- `PUT /api/tutors/me`.
- Testes negativos para refresh inválido e request protegida sem token.

## Como Rodar

1. Abra `JordaniaTeam.xcodeproj` no Xcode.
2. Garanta que o arquivo `GoogleSignIn-Info.plist` está no target do app.
3. Selecione um simulador ou device iOS 17+.
4. Rode com `Cmd + R`.

Observação: sessões antigas que tinham só `access-token` legado serão limpas no launch. Faça login novamente para receber `accessToken + refreshToken`.

## Dashboard

A tela autenticada mostra:

- `Environment`: base URL, horário local, bundle e build.
- `Session`: `userId`, email, provider, role, nome local e presença de credenciais.
- `Access token claims`: `sub`, `iss`, `iat`, `exp`, segundos até expirar, provider, role, email e name.
- `Refresh token`: presença, expiração e valor mascarado.
- `/users/me`: botão de carga, status HTTP, body bruto e DTO decodificado.
- `PUT /api/tutors/me`: formulário, preview JSON, status e body.
- `GET /api/tutors/me`: status/body; `404` é esperado antes de criar tutor.
- `Refresh`: botão de refresh manual com tokens antigos/novos mascarados.
- `Negative tests`: refresh inválido e `/users/me` sem token.
- `Event log`: login, refresh preventivo, refresh por `401`, retry, logout e erros.

Os blocos de debug usam seleção de texto para facilitar copiar payloads e claims.

## Checklist Manual

1. Faça login com Google ou Apple.
2. Confirme que a sessão mostra access token e refresh token presentes.
3. Clique em `Load /users/me` e confirme `HTTP 200`.
4. Clique em `GET tutor`; antes de criar tutor, `HTTP 404` é um estado válido.
5. Preencha `name` e `username`, confira o preview JSON e salve com `PUT /api/tutors/me`.
6. Clique em `Force refresh` e confirme que access e refresh mascarados mudaram.
7. Rode `Invalid refresh` e confirme `HTTP 401`.
8. Rode `/users/me no token` e confirme `HTTP 401/403`.
9. Faça `Sign Out` e confirme que o app volta ao login.

## Validação De Build

O projeto usa `PBXFileSystemSynchronizedRootGroup`; novos arquivos dentro de `JordaniaTeam/` entram no target automaticamente.

Nesta máquina, `xcodebuild` pode falhar se o `xcode-select` estiver apontando para Command Line Tools em vez do Xcode completo. A validação recomendada é `Cmd + B`/`Cmd + R` no Xcode.
