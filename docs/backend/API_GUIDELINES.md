# API Guidelines

**Purpose:** Define how the iOS client communicates with the Jordania backend — endpoint conventions, request construction, DTO strategy, and the authenticated request lifecycle.

**Scope:** iOS client perspective only. Does not cover backend implementation, server-side validation, or database schema. For token refresh mechanics, see `AUTHENTICATION.md`. For error types and mapping, see `ERROR_HANDLING.md`.

---

## Table of Contents

1. [Base URL](#base-url)
2. [Authenticated Requests](#authenticated-requests)
3. [Request Construction](#request-construction)
4. [DTO Strategy](#dto-strategy)
5. [Response Decoding](#response-decoding)
6. [Timeout Policy](#timeout-policy)
7. [Endpoint Catalogue](#endpoint-catalogue)

---

## Base URL

The base URL is provided by `AppConfiguration.apiBaseURL`:

| Environment | URL |
|---|---|
| Production | `https://api.redepets.xyz` |
| Debug (local) | `http://localhost:PORT` (defined in `AppConfiguration.swift`, not committed) |

All endpoint paths are appended using `URL.appendingPathComponent(_:)` — no string interpolation for URL construction.

```swift
// Correct
let url = AppConfiguration.apiBaseURL
    .appendingPathComponent("auth")
    .appendingPathComponent("login")

// Wrong
let url = URL(string: "\(baseURL)/auth/login")!
```

---

## Authenticated Requests

All requests except `POST /auth/login` and `POST /auth/refresh` require a `Bearer` token in the `Authorization` header. This is handled exclusively by `APIClient.perform(_:)`.

Callers (services like `UserService`) build a plain `URLRequest` without an `Authorization` header. `APIClient` injects the token:

```swift
// UserService: builds a plain request
let request = URLRequest(url: url)
let data = try await apiClient.perform(request)

// APIClient: adds the token internally
func authorized(_ request: URLRequest, token: String) -> URLRequest {
    var r = request
    r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return r
}
```

No service outside `Core/Networking/` should ever set an `Authorization` header manually. `BackendAuthService` is the only exception — its login and refresh endpoints handle their own auth-free requests directly.

---

## Request Construction

Requests are built using `URLRequest` directly — no request builder abstraction, no third-party HTTP client.

```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.timeoutInterval = 15
request.httpBody = try JSONEncoder().encode(body)
```

Rules:
- Always set `timeoutInterval` explicitly (15 s for authenticated requests, 10 s for logout).
- Always set `Content-Type: application/json` for POST/PUT requests with a body.
- Use `JSONEncoder()` for request bodies. Date encoding strategy is the default (`.deferredToDate`) unless the endpoint requires ISO 8601 — in which case set `.iso8601` explicitly.

---

## DTO Strategy

Data Transfer Objects are **private** to the file that uses them. They are never exposed across module boundaries.

```swift
// Correct: private DTO inside the service file
private struct LoginRequest: Encodable {
    let provider: String
    let identityToken: String
    let name: String?
    let rawNonce: String?
}

private struct AuthSessionResponse: Decodable {
    let token: String
    let userId: UUID
    let name: String?
    let email: String?
    let refreshToken: String
    let refreshExpiresAt: Date
}
```

DTOs map to domain models inside the same file via a `private` factory method or `.toModel()` function. The domain model (`AuthenticatedUser`, future `Post`, `Pet`, etc.) is what crosses file boundaries — never the DTO.

`UserService` demonstrates this with `UserMeResponse.toAuthenticatedUser()`.

---

## Response Decoding

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
return try decoder.decode(R.self, from: data)
```

Rules:
- Use `.iso8601` date decoding strategy by default.
- On `DecodingError`, throw `NetworkError.decodingError` — never let a raw `DecodingError` reach the UI.
- On a non-2xx status code, map to the appropriate error before attempting to decode (see `ERROR_HANDLING.md`).
- Never force-unwrap decoded optionals — use `guard let` and throw a typed error.

---

## Timeout Policy

| Request type | `timeoutInterval` |
|---|---|
| Login / refresh (auth-critical) | 15 s |
| Authenticated API requests | 15 s |
| Logout (best-effort) | 10 s |

Timeouts are set per-request, not on `URLSession`. `URLSession.shared` is used throughout — no custom session configuration is needed at this stage.

---

## Endpoint Catalogue

Endpoints currently implemented on the iOS client:

| Method | Path | Service | Auth required |
|---|---|---|---|
| `POST` | `/auth/login` | `BackendAuthService.login` | No |
| `POST` | `/auth/refresh` | `BackendAuthService.refresh` | No |
| `POST` | `/auth/logout` | `BackendAuthService.logout` | Bearer (manual) |
| `GET` | `/users/me` | `UserService.fetchCurrentUser` | Bearer (via APIClient) |

As new features (Feed, Posts, Map, Profile, Search) add endpoints, they are documented here with their corresponding service and authentication requirement.
