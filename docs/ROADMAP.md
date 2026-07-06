# Roadmap

**Purpose:** Tracks what has been built, what is in progress, and what comes next.

**Scope:** Phases, features, and engineering milestones. Implementation details belong in the relevant architecture or feature documents. This document describes scope and status, not how things are built.

---

## Table of Contents

1. [Current Status](#current-status)
2. [Phase 1 — Foundation](#phase-1--foundation)
3. [Phase 1.5 — Engineering Hardening](#phase-15--engineering-hardening)
4. [Phase 2 — Core Features](#phase-2--core-features)
5. [Phase 3 — Polish and Launch](#phase-3--polish-and-launch)
6. [Explicitly Deferred](#explicitly-deferred)

---

## Current Status

**Phase 1 is complete. Phase 1.5 (Engineering Hardening) is complete.**

The current build:
- Launches and routes to authentication or the main tab interface based on persisted session state.
- Supports Sign in with Apple and Google Sign-In, both flowing through a backend token exchange.
- Persists the authenticated session and JWT tokens in the Keychain.
- Performs automatic session validation on launch and handles token refresh transparently.
- Exposes four main tabs: Feed, Map, Profile, and Search.
- All four tabs are scaffolded. Their content is not yet implemented.
- 53 automated tests passing across unit and integration targets (41 unit + 12 integration).

---

## Phase 1 — Foundation

**Status: Complete**

Phase 1 established the engineering skeleton of the application. The goal was not features — it was correctness of the infrastructure that every future feature depends on.

### Completed

**App structure**
- `App/` layer with `JordaniaTeamApp`, `AppContainer`, `RootView`, and `MainTabView`.
- `AppContainer` as the single composition root, wiring all dependencies at launch.
- `RootView` routing between authentication flow and main interface based on `SessionState`.
- `MainTabView` with four tabs: Feed, Map, Profile, Search.

**Session management**
- `SessionStore` as the observable, single source of truth for authentication state.
- `SessionState` machine with four states: `.loading`, `.authenticated`, `.signedOut`, `.error`.
- `AuthenticatedUser` model persisted in the Keychain via `SessionPersistence`.
- Automatic session restoration on launch from Keychain.
- Session validation against the backend on launch (`UserService.fetchCurrentUser`).
- Graceful handling of `401 Unauthorized` — automatic sign-out without user disruption.

**Authentication**
- Sign in with Apple via `AppleAuthService` and `AuthenticationServices`.
- Google Sign-In via `GoogleAuthService` and the official `GoogleSignIn` SDK.
- Backend token exchange via `BackendAuthService` — both providers exchange their identity token for a Jordania JWT.
- `TokenProvider` with transparent JWT refresh — the `APIClient` never makes a call with an expired token.

**Security**
- `KeychainService` — all token and session persistence through the system Keychain.
- JWT lives exclusively in `Core/Security`. The UI layer has no access to token values.
- `Core/Security/JWT.swift` — JWT parsing for expiry inspection, without a third-party dependency.

**Networking**
- `APIClient` — single HTTP client used by all features, with automatic token injection and refresh.
- `NetworkError` — typed error taxonomy covering all failure modes from the network layer.
- Environment-aware base URL: `http://localhost:8080` in DEBUG, `https://api.redepets.xyz` in production.

**Feature scaffolding**
- `Features/Authentication` — the sign-in UI feature.
- `Features/Feed` — scaffolded, content pending.
- `Features/Map` — scaffolded, content pending.
- `Features/Posts` — scaffolded, content pending.
- `Features/Profile` — scaffolded, content pending.
- `Features/Search` — scaffolded, content pending.

**Engineering documentation**
- `docs/` directory with the full documentation structure (19 Markdown files).
- Core project documentation (this phase).

---

## Phase 1.5 — Engineering Hardening

**Status: Complete**

Phase 1.5 added automated test coverage across the core infrastructure built in Phase 1. The goal was to prove that the session management, token handling, networking, and authentication layers are correct — and to establish the testing patterns the project will use going forward.

### Completed

**Unit tests — `JordaniaTeamTests` (41 tests)**
- `SessionStore`: all `SessionState` transitions, Keychain persistence, cold launch restoration, sign-out.
- `SessionPersistence`: save/load round-trips, expired token handling, clearAll.
- `TokenProvider`: proactive refresh, reactive refresh after 401, concurrent call coalescing, session expiry sign-out.
- `APIClient`: success path, 401 → refresh → retry, 401 → refresh → 401 → sign-out, network error mapping.
- `JWT`: `isExpired` and `needsRefresh` boundary conditions, malformed token handling.
- `AuthViewModel`: loading state, error messages, cancellation handling, duplicate tap prevention.
- `NetworkError`: all `URLError` mapping cases.

**Integration tests — `JordaniaTeamIntegrationTests` (12 tests)**
- `BackendAuthService Integration`: HTTP request/response cycle with `MockURLProtocol` — 200 decode, 401, 500, invalid payload.
- `SessionPersistence Integration`: real `SessionPersistence` + `InMemoryKeychainService` — save/load, expiry, clear.
- `SessionStore Integration`: real `SessionStore` + real `SessionPersistence` + `InMemoryKeychainService` — full sign-in/sign-out/restore cycle.

**Testing infrastructure**
- `MockURLProtocol` — `URLProtocol` subclass that intercepts all requests on a test-scoped `URLSession`.
- `TestURLSessionFactory` — creates an ephemeral `URLSession` with `MockURLProtocol` registered.
- `InMemoryKeychainService` — in-memory `KeychainService` substitute for tests that cannot access the real Keychain.
- `AuthFixtures` — deterministic HTTP response fixtures (success, 401, 500, invalid payload).

---

## Phase 2 — Core Features

**Status: Not started**

Phase 2 implements the primary product loop: a user can sign in, create a pet profile, publish posts, see a feed of content from other pets, and find nearby pets on the map.

### Planned scope

**Profile feature**
- User profile view: display name, avatar, bio.
- Pet creation: name, species, breed, date of birth, photo.
- Pet profile view: pet details and associated posts.
- Edit profile and edit pet flows.

**Feed feature**
- Timeline of posts from pets the user follows.
- Post card: pet avatar, pet name, image, caption, timestamp.
- Pull-to-refresh and pagination.

**Posts feature**
- Post creation: photo selection, caption, pet attribution.
- Post detail view.
- Post deletion (owner only).

**Map feature**
- Map view showing locations of nearby pets (opt-in location sharing).
- Pet card on pin tap.
- Location permission handling.

**Search feature**
- Search by user name, pet name, or breed.
- Results presented as a list of pet profiles.

**Follow system**
- Follow and unfollow a pet.
- Following list and followers list on the pet profile.

---

## Phase 3 — Polish and Launch

**Status: Not started**

Phase 3 completes the application for App Store submission.

### Planned scope

- Accessibility audit: VoiceOver, Dynamic Type, minimum tap targets.
- Performance profiling: launch time, scroll performance, memory footprint.
- Onboarding flow: first-launch experience after authentication, pet creation prompt.
- Push notifications: new follower, new post from a followed pet.
- App Store assets: screenshots, App Preview, metadata.
- Privacy manifest and required reason APIs declaration.
- Final security review: Keychain attributes, ATS configuration, no sensitive data in logs.

---

## Explicitly Deferred

These items are out of scope for the current project lifecycle. They are listed here to prevent them from being rediscovered and re-evaluated during active development.

| Item | Reason deferred |
|---|---|
| iPad-specific layout | Jordania is designed for iPhone. iPad runs the iPhone layout. A dedicated iPad layout requires design work not planned. |
| macOS Catalyst | Out of scope. The project does not maintain a Mac target. |
| Web client | No web interface is planned. The product is iOS-native. |
| Backend infrastructure ownership | The backend at `api.redepets.xyz` is maintained separately. iOS does not own that codebase. |
| Real-time features (WebSocket, live feed) | Phase 2 uses polling or pull-to-refresh. Push-based real-time updates are a post-launch consideration. |
| Monetisation | No in-app purchases, subscriptions, or advertising. |
| Analytics and crash reporting | No third-party analytics SDK is planned. Apple's built-in crash reporting via Xcode Organiser is sufficient for this stage. |
