# Error Handling

**Purpose:** Define how errors are categorised, propagated, and presented in Jordania — from network transport failures to domain-specific authentication errors.

**Scope:** iOS client error taxonomy and handling patterns. Does not cover backend error response format design (that is a backend concern) or SwiftUI error presentation components (see `UI_GUIDELINES.md`).

---

## Table of Contents

1. [Error Taxonomy](#error-taxonomy)
2. [Error Propagation](#error-propagation)
3. [User-Facing Messages](#user-facing-messages)
4. [Logging](#logging)
5. [Terminal Errors](#terminal-errors)
6. [Silent Errors](#silent-errors)

---

## Error Taxonomy

Jordania uses two distinct error types. They must never be merged.

### `NetworkError`

Transport and HTTP protocol failures. Lives in `Core/Networking/NetworkError.swift`.

| Case | Meaning |
|---|---|
| `.noConnection` | `URLError`: not connected, connection lost, data not allowed |
| `.timeout` | `URLError.timedOut` |
| `.cancelled` | `URLError.cancelled` — silent, no UI message |
| `.invalidResponse` | Non-HTTP response or unexpected URLSession failure |
| `.unauthorized` | HTTP 401 — after token refresh has already been attempted |
| `.decodingError` | `JSONDecoder` failed to parse a valid response |
| `.encodingError` | `JSONEncoder` failed to encode a request body |
| `.serverError(statusCode:)` | Any non-2xx, non-401 HTTP status |

Status codes and technical details are stored as associated values for logging and testing. They **never appear in `errorDescription`** — only user-safe messages do.

### `AuthError`

Authentication domain failures. Lives in `Core/Authentication/AuthError.swift`.

| Case | Meaning |
|---|---|
| `.failed(String)` | Generic auth failure with a UI-safe message |
| `.cancelled` | User dismissed the Apple or Google sign-in sheet — silent |
| `.sessionExpired` | Refresh token rejected by backend (401 on `/auth/refresh`) — terminal |

### Separation rule

`AuthError` is produced in `Core/Authentication/`. `NetworkError` is produced in `Core/Networking/`. The mapping from `NetworkError.unauthorized` to `AuthError.sessionExpired` happens at exactly one place: `BackendAuthService.refresh`.

---

## Error Propagation

Errors flow upward through `throws` / `async throws` until they reach a ViewModel. The ViewModel is the terminal handler for user-visible errors.

```
BackendAuthService.login  →  throws AuthError or NetworkError
AppleAuthService.handle   →  throws AuthError
AuthViewModel.performSignIn
    catch AuthError.cancelled       → silent
    catch NetworkError.cancelled    → silent
    catch NetworkError              → errorMessage = networkError.errorDescription
    catch                           → errorMessage = generic fallback
```

Services **do not catch errors** they cannot meaningfully handle. They throw and let the ViewModel decide the UI response.

The one exception: `BackendAuthService.logout` is fire-and-forget. Network failures are logged and swallowed — logout is never blocked by a network error.

---

## User-Facing Messages

All user-visible error messages come from `LocalizedError.errorDescription`.

Rules:
- `errorDescription` must be written for the user, not for the developer.
- Technical details (status codes, underlying error types) must never appear in `errorDescription`.
- `NetworkError.cancelled` returns `nil` from `errorDescription` — cancellation is never shown to the user.
- `AuthError.failed(String)` carries the message directly; the string is set at the call site and must be safe to display.

```swift
// Correct: user-safe message in errorDescription
case .unauthorized: return "Sessão expirada. Faça login novamente."

// Wrong: technical details in errorDescription
case .serverError(let code): return "Server returned HTTP \(code)"
```

ViewModels display `errorDescription` directly. They do not transform or interpolate error messages.

---

## Logging

All logging uses `OSLog` with a consistent subsystem and per-component category:

```swift
private static let logger = Logger(subsystem: "app.jordania", category: "APIClient")
```

| Category | File |
|---|---|
| `"BackendAuth"` | `BackendAuthService` |
| `"TokenProvider"` | `TokenProvider` |
| `"APIClient"` | `APIClient` |
| `"Session"` | `SessionStore` |
| `"Keychain"` | `KeychainService` |
| `"GoogleAuth"` | `GoogleAuthService` |

Log levels:
- `.error` — recoverable failures that degraded a request (decode error, HTTP 4xx/5xx).
- `.fault` — data integrity violations that should never happen (Keychain clear failure on logout).
- `.warning` — expected-but-notable failures that were handled gracefully (session validation failed due to network, staying authenticated).
- `.info` — significant lifecycle events (refresh triggered, refresh succeeded).

Token strings are never logged. When logging request details that may include sensitive data, use `privacy: .private`:

```swift
Self.logger.error("Request falhou com status \(status): \(detail, privacy: .private)")
```

---

## Terminal Errors

A terminal error is one that cannot be retried and requires immediate sign-out.

Only one error is terminal: **`AuthError.sessionExpired`**.

This error is thrown when `POST /auth/refresh` returns 401. It signals that the refresh token is expired, revoked, or that token reuse was detected. The correct response is always `SessionStore.signOut()` — no retry, no UI prompt to try again.

The path is: `BackendAuthService.refresh` throws `AuthError.sessionExpired` → `TokenProvider.executeRefresh` catches it → calls `sessionStore?.signOut()` → `RootView` transitions to `AuthView`.

---

## Silent Errors

The following errors are always silent (no UI message, no error state):

| Error | Reason |
|---|---|
| `AuthError.cancelled` | User dismissed the sign-in sheet deliberately |
| `NetworkError.cancelled` | Task was cancelled programmatically |
| `BackendAuthService.logout` failure | Logout is local-first; server revocation is best-effort |
| `SessionStore.validateSession` non-401 network error | Preserves session on connectivity issues; does not force re-auth |

Silent handling is always explicit in code — a `catch` block that does nothing must include a comment explaining why silence is correct.
