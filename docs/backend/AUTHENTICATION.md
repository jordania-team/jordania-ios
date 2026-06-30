# Authentication

**Purpose:** Documents the authentication architecture for Jordania — how identity is established, tokens are managed, and sessions are maintained between the iOS client and the backend.

**Scope:** Authentication flows and security contracts only. API request/response conventions belong in [API_GUIDELINES.md](API_GUIDELINES.md). Error handling belongs in [ERROR_HANDLING.md](ERROR_HANDLING.md). iOS-side session state belongs in Core/Session (see [architecture/PROJECT_STRUCTURE.md](../architecture/PROJECT_STRUCTURE.md)).

---

## Table of Contents

1. [Authentication Providers](#authentication-providers)
2. [Token Architecture](#token-architecture)
3. [Token Storage](#token-storage)
4. [Session Lifecycle](#session-lifecycle)
5. [Security Requirements](#security-requirements)
6. [Backend Contract](#backend-contract)

---

## Authentication Providers

<!-- Placeholder: Sign in with Apple (primary), Google Sign-In (secondary) — which is required for App Store, which is optional, and the rationale -->

## Token Architecture

<!-- Placeholder: JWT structure used, access token vs refresh token strategy, token expiry policy -->

## Token Storage

<!-- Placeholder: Keychain as the only acceptable storage for tokens, what attributes to use (kSecAttrAccessible), what is forbidden (UserDefaults, memory-only) -->

## Session Lifecycle

<!-- Placeholder: how a session is created on successful auth, how it is restored on app launch, how it is terminated on sign-out or token revocation -->

## Security Requirements

<!-- Placeholder: certificate pinning policy, minimum TLS version, token rotation rules, what happens on authentication failure -->

## Backend Contract

<!-- Placeholder: expected endpoints for token exchange, refresh, and revocation — request/response shape, HTTP status semantics -->
