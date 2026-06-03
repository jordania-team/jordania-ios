# Auth Playground - iOS

Laboratório de autenticação iOS com múltiplos providers, construido em SwiftUI com mentalidade Apple-first.

> Objetivo: validar a complexidade real de suportar mais de um provider de autenticação em um app iOS nativo, antes de implementar no produto principal.

---

## Stack

- Swift 5.10+
- SwiftUI
- iOS 17+
- AuthenticationServices (Apple)
- GoogleSignIn SDK (Google)
- SwiftData (POC 3)

---

## POCs

### POC 1 — Sign in with Apple
**Branch:** `feat/poc-1-apple-sign-in`

Valida o fluxo completo de autenticação com Apple:
- Botão oficial `SignInWithAppleButton`
- Estados: `signedOut` / `loading` / `signedIn` / `error`
- Sessão em memória
- Sign out local
- Tratamento de cancelamento e erro

### POC 2 — Google Sign-In
**Branch:** `feat/poc-2-google-sign-in`

Adiciona Google ao mesmo app, usando a mesma arquitetura base do POC 1:
- SDK oficial `GoogleSignIn`
- Tratamento de `onOpenURL` e restore de sessão
- Comparação do delta de complexidade vs Apple

### POC 3 — Persistência local
**Branch:** `feat/poc-3-swiftdata-session`

Adiciona persistência local com SwiftData:
- Cache local de sessão/perfil
- Restauração de estado ao reabrir o app
- Limpeza correta no sign out
- Valida consistência entre estado do provider e estado local

---

## Arquitetura

Estrutura simples em camadas leves, adequada para POC profissional:

```
AuthPlayground/
├── App/                  # Entry point e composição
├── Features/
│   └── Auth/
│       ├── Views/        # Telas (sem lógica de negócio)
│       └── ViewModels/   # Estado e coordenação de UI
├── Core/
│   ├── Authentication/   # Serviços e providers de auth
│   └── Session/          # Estado global de sessão
└── Models/               # Modelos de domínio simples
```

---

## Princípios

- Apple Human Interface Guidelines
- Swift moderno e idiomático
- Sem overengineering
- Separação clara de responsabilidades
- Testabilidade por design
- Cada POC responde uma pergunta técnica específica
