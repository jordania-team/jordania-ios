# Auth Playground — iOS

Laboratório de autenticação iOS com múltiplos providers, construído em SwiftUI com mentalidade Apple-first.

> Objetivo: validar a complexidade real de suportar mais de um provider de autenticação em um app iOS nativo, antes de implementar no produto principal.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Linguagem | Swift 5.10+ |
| UI | SwiftUI |
| Plataforma | iOS 17+ |
| Auth Apple | AuthenticationServices |
| Auth Google | GoogleSignIn SDK |
| Persistência | SwiftData (POC 3) |

---

## Pré-requisitos

- Xcode 16+
- iOS 17+ (simulador ou device)
- Conta Apple Developer (para Sign in with Apple)
- Credenciais Google configuradas no `GoogleService-Info.plist`

---

## Configuração local

### 1. Clonar o repositório

```bash
git clone https://github.com/ghabrielferrari/auth-playground-ios.git
```

### 2. Abrir no Xcode

Abra o arquivo `.xcodeproj` diretamente. Não é necessário nenhum passo adicional de build — as dependências são gerenciadas via Swift Package Manager.

### 3. Configurar Google Sign-In

Copie o arquivo `GoogleService-Info.plist` com as credenciais do projeto para dentro do target antes de rodar.

### 4. Rodar

Selecione o simulador ou device e pressione `Cmd + R`.

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

## Estrutura do projeto

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
- Swift moderno e idiomático — async/await, Observation, tipos value
- Sem overengineering — cada camada tem razão de existir
- Separação clara de responsabilidades
- Testabilidade por design
- Cada POC responde uma pergunta técnica específica
