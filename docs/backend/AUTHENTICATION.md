# Authentication

**Purpose:** Document the authentication contract between the Jordania iOS client and the backend — flows, token lifecycle, Keychain storage, and security invariants.

**Scope:** iOS-side implementation only. Backend server implementation is out of scope. For networking mechanics (request retry, 401 handling), see `API_GUIDELINES.md`. For error types, see `ERROR_HANDLING.md`.

---

## Table of Contents

1. [Overview](#overview)
2. [Supported Providers](#supported-providers)
3. [Login Flow](#login-flow)
4. [Token Storage](#token-storage)
5. [Token Lifecycle](#token-lifecycle)
6. [Session Validation](#session-validation)
7. [Logout](#logout)
8. [Security Invariants](#security-invariants)

---

## Overview

Jordania uses **OAuth identity token exchange**: the iOS client authenticates with Apple or Google, obtains an identity token from the provider, and exchanges it with the Jordania backend (`POST /auth/login`). The backend returns a JWT access token and a refresh token. All subsequent API calls are authenticated with the JWT.

The client never handles passwords. The backend owns credential validation.

---

## Supported Providers

| Provider | `AuthProvider.rawValue` | iOS Service |
|---|---|---|
| Apple | `"apple"` | `AppleAuthService` via `AuthenticationServices` |
| Google | `"google"` | `GoogleAuthService` via `GoogleSignIn` SDK |

The `rawValue` strings are the backend contract. They are lowercase; the backend may return them uppercased — `AuthProvider` decodes case-insensitively.

---

## Login Flow

### Apple

```
SignInWithAppleButton.onRequest
  └─ AppleAuthService.prepareNonce()          → SHA-256 hash sent to Apple
SignInWithAppleButton.onCompletion
  └─ AppleAuthService.handle(_:)
       ├─ Validates credential + nonce
       ├─ Persists pending full name (UserDefaults, one-time delivery)
       └─ BackendAuthService.login(provider: .apple, identityToken:, rawNonce:)
            └─ POST /auth/login
                 └─ SessionStore.signIn(user:accessToken:refreshToken:)
```

**Nonce requirement:** Apple mandates a cryptographic nonce to prevent replay attacks. `prepareNonce()` generates a random nonce, stores it in `currentNonce`, and returns its SHA-256 hash for the Apple request. The raw nonce is sent to the backend, which verifies the hash against Apple's servers.

**Full name one-time delivery:** Apple sends `fullName` only on the first login. `AppleAuthService` persists a `PendingAppleName` (keyed by `credential.user`) in `UserDefaults` and clears it after a successful backend response. This survives network failures between the Apple callback and the backend response.

### Google

```
GoogleSignInButton.action
  └─ GoogleAuthService.signIn()
       ├─ GIDSignIn.sharedInstance.signIn(withPresenting:)   ← PKCE + state gerenciados pelo SDK
       └─ BackendAuthService.login(provider: .google, identityToken:)
            └─ POST /auth/login
                 └─ SessionStore.signIn(user:accessToken:refreshToken:)
```

Google session restoration is **not used**. The JWT in the Keychain is the sole source of session truth. `GIDSignIn.restorePreviousSignIn` is never called.

#### PKCE (RFC 7636)

O fluxo OAuth 2.0 do Google requer PKCE para prevenir **code interception attacks** — um atacante que intercepte o `authorization_code` (via URI scheme hijacking ou logs) não consegue trocá-lo por tokens sem o `code_verifier` original.

O GoogleSignIn SDK implementa PKCE automaticamente:

| Etapa | Responsável | O que acontece |
|---|---|---|
| Geração do `code_verifier` | SDK | Valor aleatório criptográfico (≥ 256 bits), nunca exposto |
| Derivação do `code_challenge` | SDK | `BASE64URL(SHA-256(code_verifier))` |
| Authorization request | SDK | Envia `code_challenge` + `code_challenge_method=S256` |
| Token exchange | SDK | Envia `code_verifier`; Google valida antes de emitir tokens |
| Geração do `state` | SDK | Parâmetro CSRF, validado automaticamente no callback |

Nenhum código manual de PKCE é necessário ou possível — o SDK não expõe o `code_verifier` e não permite sobrescrevê-lo. O único valor que atravessa para o backend Jordania é o `idToken` emitido pelo Google após a autenticação bem-sucedida.

**Comparação Apple vs Google:**

| Mecanismo | Apple | Google |
|---|---|---|
| Proteção contra replay | Nonce (SHA-256, manual) | PKCE code_verifier (SHA-256, SDK) |
| Implementação iOS | `AppleAuthService.prepareNonce()` | Automática via GoogleSignIn SDK |
| Valor enviado ao backend | `rawNonce` | nenhum (apenas `idToken`) |
| Validação servidor | Backend verifica hash com Apple | Google valida na troca do code |

---

## Token Storage

All tokens are stored in the iOS Keychain under service `"app.jordania.auth"`.

| Keychain Account | Contents | Accessibility |
|---|---|---|
| `"current-session"` | `AuthenticatedUser` (JSON-encoded) | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| `"access-token"` | JWT access token string | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| `"refresh-token"` | Refresh token string | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |

`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is chosen because:
- `AfterFirstUnlock` allows background operations (e.g., session validation) after the device is unlocked once.
- `ThisDeviceOnly` prevents token migration to a new device via iCloud Keychain backup.

**`AuthenticatedUser` and tokens are stored separately.** `SessionStore` reads the user for UI rendering; `TokenProvider` reads the tokens for API authentication. Neither crosses into the other's domain.

---

## Token Lifecycle

### Access Token

- **Format:** JWT.
- **Validation:** Local claims reading via `JWT.swift` for UX decisions only (proactive refresh). Signature validation is always performed server-side.
- **Expiry leeway:** `JWT.isExpired` treats a token as expired if it expires within 30 seconds, preventing a 401 on the first call after launch.
- **Proactive refresh trigger:** `JWT.needsRefresh` returns `true` if the token expires within 10 minutes. `TokenProvider.validAccessToken()` calls this before every request.

### Refresh Token

- Stored in Keychain; never exposed in `SessionStore` or any observable property.
- Used exclusively by `TokenProvider.executeRefresh()` via `BackendAuthService.refresh(refreshToken:)`.
- A `401` from `POST /auth/refresh` means the token is expired, revoked, or a reuse was detected. This maps to `AuthError.sessionExpired` and triggers immediate sign-out — it is **not retried**.

### Refresh coalescing

`TokenProvider` is an `actor`. If multiple concurrent requests trigger a refresh simultaneously, a single `Task<String, Error>` is created and all callers `await` the same result. This prevents duplicate refresh requests and race conditions on the Keychain write.

### Reactive refresh (401 recovery)

If `APIClient` receives a `401` despite a valid-looking token, it calls `TokenProvider.forceRefresh()`. A second `401` after the refresh is terminal: `SessionStore.signOut()` is called and `NetworkError.unauthorized` is thrown. There is no third attempt.

---

## Session Validation

`SessionStore.validateSession(using:)` is called:
1. On app launch, via `JordaniaTeamApp.body.task`.
2. Every time the app returns to the foreground (`scenePhase == .active`).

Behaviour:
- If no `currentUser` is present, returns immediately (user is already signed out).
- On success (`GET /users/me` returns 200), updates `currentUser` with fresh data from the backend.
- On `NetworkError.unauthorized` (401), calls `signOut()`.
- On any other network error, logs a warning and keeps the current `.authenticated` state — network failures do not force the user to re-authenticate.

---

## Logout

Logout is **local-first**:

```swift
func signOut() {
    currentUser = nil
    state = .signedOut      // UI updates immediately
    try? persistence.clearAll()  // Best-effort Keychain clear
}
```

The UI transitions to `.signedOut` before the Keychain operation completes. If the Keychain clear fails, the fault is logged but the user is not blocked from signing out.

`BackendAuthService.logout(accessToken:)` is called best-effort to revoke the refresh token server-side. Network failures are logged and ignored — they do not prevent local sign-out.

For Google sign-ins, `GIDSignIn.sharedInstance.signOut()` is called before `SessionStore.signOut()` to clear the Google SDK's local state.

---

## Security Invariants

1. **JWT is never in observable properties.** `SessionStore.currentUser` is an `AuthenticatedUser`. Tokens are never exposed to SwiftUI views.
2. **Tokens are never logged.** All `Logger` calls in auth-related files use `privacy: .private` for sensitive values and never reference token strings.
3. **Raw nonce is consumed once.** `AppleAuthService` sets `currentNonce = nil` in a `defer` block at the start of `handle(_:)`, regardless of outcome.
4. **Refresh token is never in `AuthenticatedUser`.** The model carries identity information only. Tokens have a separate, isolated storage path.
5. **Backend owns signature validation.** `JWT.swift` parses claims locally for UX purposes only. The project never validates the JWT signature on the client.
6. **PKCE is guaranteed for Google Sign In.** `GIDSignIn.sharedInstance.signIn(withPresenting:)` always executes the full PKCE flow (RFC 7636) internally. No authorization code exchange is possible without the matching `code_verifier`. The `code_verifier` is generated and held exclusively by the SDK — it is never accessible or overridable from application code.
