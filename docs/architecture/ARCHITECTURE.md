# Architecture

**Purpose:** Describe the structural layers of the Jordania iOS application, the responsibilities of each layer, and how dependencies flow between them.

**Scope:** High-level architecture only — layers, key types, and the composition model. File placement rules live in [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md). Navigation flow lives in [NAVIGATION.md](NAVIGATION.md). The reasoning behind every major decision lives in [DECISION_LOG.md](DECISION_LOG.md).

---

## Table of Contents

1. [Architectural Style](#architectural-style)
2. [Layers](#layers)
3. [Composition Root](#composition-root)
4. [Dependency Graph](#dependency-graph)
5. [Data Flow](#data-flow)
6. [Concurrency Model](#concurrency-model)
7. [Key Types Reference](#key-types-reference)

---

## Architectural Style

Jordania uses **Feature-Based Lightweight MVVM**.

- The project is organised around **features** (`Feed`, `Map`, `Profile`, `Search`, `Authentication`), not around layers (`Models`, `Services`, `ViewModels`).
- Each feature owns its own Views, ViewModels, and models. There is no global `Models/` folder.
- The MVVM layer is kept lightweight: ViewModels hold UI state and orchestrate service calls. They contain no business logic beyond what is needed to drive the view.
- Shared infrastructure lives in `Core/`. Reusable UI-only components live in `Shared/`.
- There is **no premature modularisation** into Swift packages. The project is a single target.

---

## Layers

```
┌─────────────────────────────────────────────────┐
│                   App Layer                     │
│  JordaniaTeamApp · AppContainer · RootView      │
│  MainTabView · AppConfiguration                 │
├─────────────────────────────────────────────────┤
│                 Feature Layer                   │
│  Features/Authentication  Features/Feed         │
│  Features/Map  Features/Profile  Features/Search│
├─────────────────────────────────────────────────┤
│                  Core Layer                     │
│  Session · Authentication · Networking          │
│  Security · User                                │
├─────────────────────────────────────────────────┤
│                 Shared Layer                    │
│  DesignSystem · Reusable UI Components          │
└─────────────────────────────────────────────────┘
```

### App Layer
Application lifecycle, composition, and top-level navigation. Nothing in this layer contains business logic.

- **`JordaniaTeamApp`** — `@main` entry point. Instantiates `AppContainer`, handles scene phase changes, and delegates URL handling to Google Sign-In.
- **`AppContainer`** — Composition root. Builds and wires the entire dependency graph. The only place where concrete types are instantiated and connected.
- **`AppConfiguration`** — Centralises environment values (`apiBaseURL`). An `enum` with `static let` properties; never instantiated.
- **`RootView`** — Reads `SessionStore.state` and routes to the correct top-level view. Contains no business logic.
- **`MainTabView`** — Renders the authenticated tab structure. Owned by `App/` because it is an application-level concern, not a feature.

### Feature Layer
Self-contained vertical slices. Each feature folder contains `Views/` and `ViewModels/`. Models that belong exclusively to a feature live inside that feature.

Current features: `Authentication`, `Feed`, `Map`, `Profile`, `Search`.

**Dependency rule:** Features may depend on `Core/` and `Shared/`. Features must never import each other.

### Core Layer
Cross-cutting infrastructure shared by multiple features.

| Subfolder | Contents | Key Types |
|---|---|---|
| `Core/Session/` | Authentication state and its persistence contract | `SessionStore`, `SessionState`, `AuthenticatedUser`, `SessionPersistence`, `SessionPersistenceProtocol` |
| `Core/Authentication/` | Provider services and token lifecycle | `AppleAuthService`, `GoogleAuthService`, `BackendAuthService`, `BackendAuthServiceProtocol`, `TokenProvider`, `AuthError` |
| `Core/Networking/` | HTTP execution and error taxonomy | `APIClient`, `NetworkError` |
| `Core/Security/` | Keychain abstraction and JWT utilities | `KeychainService`, `JWT` |
| `Core/User/` | User data fetching | `UserService` |

### Shared Layer
Reusable, UI-only components with no dependencies on `Core/` or any feature. Contains design tokens (`BrandColor`, `BrandSpacing`) and generic SwiftUI components.

---

## Composition Root

`AppContainer` is instantiated exactly once, as a `private let` property of `JordaniaTeamApp`. It is the only place in the codebase where concrete dependencies are created and wired together.

**Construction order inside `AppContainer.init`:**

```
SessionPersistence
    └─► SessionStore            (receives persistence)
    └─► BackendAuthService
    └─► TokenProvider           (receives persistence + authService + sessionStore)
            └─► APIClient       (receives tokenProvider + urlSession + sessionStore)
                    └─► UserService   (receives apiClient)

AuthViewModel                   (receives sessionStore)
```

**Bootstrap:** Third-party SDK configuration (`GIDSignIn`) is performed in `AppContainer.bootstrap()`, called explicitly by `JordaniaTeamApp` after the window is ready. This keeps `init` pure and testable.

---

## Dependency Graph

```
JordaniaTeamApp
  └── AppContainer (@MainActor)
        ├── SessionStore (@Observable @MainActor)
        │     └── SessionPersistence
        │           └── KeychainService
        ├── TokenProvider (actor)
        │     ├── SessionPersistence        [via SessionPersistenceProtocol]
        │     ├── BackendAuthService        [via BackendAuthServiceProtocol]
        │     └── SessionStore (weak)
        ├── APIClient (actor)
        │     ├── TokenProvider
        │     ├── URLSession
        │     └── SessionStore (weak)
        ├── AuthViewModel (@Observable @MainActor)
        │     ├── SessionStore
        │     ├── AppleAuthService
        │     └── GoogleAuthService
        └── UserService
              └── APIClient
```

Arrows represent "depends on / holds a reference to". `SessionStore` is held weakly by `TokenProvider` and `APIClient` to avoid retain cycles. `TokenProvider` depends on `SessionPersistenceProtocol` and `BackendAuthServiceProtocol` — concrete types are injected at the `AppContainer` composition root.

---

## Data Flow

### Authentication
```
User taps "Sign in with Apple"
  → AuthView → AuthViewModel.handleAppleSignIn()
  → AppleAuthService.handle() → BackendAuthService.signInWithApple()
  → Returns AuthSession (user + accessToken + refreshToken)
  → SessionStore.signIn()   [saves to Keychain, updates state to .authenticated]
  → RootView observes SessionStore.state → renders MainTabView
```

### Authenticated Request
```
Feature ViewModel calls UserService / future service
  → Service builds URLRequest (no auth header)
  → APIClient.perform() fetches valid token from TokenProvider
  → TokenProvider: if token expires in < 10 min → proactive refresh
  → APIClient injects Bearer header → URLSession executes
  → 401 received → APIClient calls TokenProvider.forceRefresh() (coalesced)
  → Second 401 → SessionStore.signOut() → NetworkError.unauthorized thrown
```

### Session Validation on Launch
```
JordaniaTeamApp.task
  → AppContainer.bootstrap()        [configures Google Sign-In SDK]
  → SessionStore.validateSession()  [calls UserService.fetchCurrentUser()]
  → Success: state stays .authenticated, currentUser refreshed
  → 401: SessionStore.signOut() → state = .signedOut
  → Network error: warning logged, state stays .authenticated (offline tolerance)
```

---

## Concurrency Model

| Type | Isolation | Reason |
|---|---|---|
| `SessionStore` | `@MainActor` | Drives SwiftUI state; mutations must be on main thread |
| `AppContainer` | `@MainActor` | Composes `@MainActor` types at startup |
| `AuthViewModel` | `@MainActor` | Drives SwiftUI state |
| `APIClient` | `actor` | Manages in-flight requests; shared from multiple callers |
| `TokenProvider` | `actor` | Coalesces concurrent refresh requests without data races |
| `SessionPersistence` | None (synchronous) | Keychain calls are synchronous and fast |
| `BackendAuthService` | None (`async` methods) | Stateless; callers manage concurrency |
| `UserService` | None (`async` methods) | Stateless struct; callers manage concurrency |

---

## Key Types Reference

| Type | File | Layer | Role |
|---|---|---|---|
| `JordaniaTeamApp` | `App/JordaniaTeamApp.swift` | App | Entry point, scene lifecycle |
| `AppContainer` | `App/AppContainer.swift` | App | Composition root |
| `AppConfiguration` | `App/AppConfiguration.swift` | App | Environment configuration |
| `RootView` | `App/RootView.swift` | App | Top-level navigation router |
| `MainTabView` | `App/MainTabView.swift` | App | Authenticated tab bar |
| `SessionStore` | `Core/Session/SessionStore.swift` | Core | Auth state source of truth |
| `SessionState` | `Core/Session/SessionState.swift` | Core | Auth state machine cases |
| `AuthenticatedUser` | `Core/Session/AuthenticatedUser.swift` | Core | Session identity model |
| `SessionPersistence` | `Core/Session/SessionPersistence.swift` | Core | Keychain read/write facade |
| `SessionPersistenceProtocol` | `Core/Session/SessionPersistenceProtocol.swift` | Core | Testability contract for session persistence |
| `TokenProvider` | `Core/Authentication/TokenProvider.swift` | Core | Token lifecycle + coalescing |
| `BackendAuthService` | `Core/Authentication/BackendAuthService.swift` | Core | OAuth → JWT exchange |
| `BackendAuthServiceProtocol` | `Core/Authentication/BackendAuthServiceProtocol.swift` | Core | Testability contract for backend auth |
| `AppleAuthService` | `Core/Authentication/AppleAuthService.swift` | Core | Sign in with Apple |
| `GoogleAuthService` | `Core/Authentication/GoogleAuthService.swift` | Core | Google Sign-In |
| `APIClient` | `Core/Networking/APIClient.swift` | Core | Authenticated HTTP executor |
| `NetworkError` | `Core/Networking/NetworkError.swift` | Core | Transport error taxonomy |
| `KeychainService` | `Core/Security/KeychainService.swift` | Core | Keychain CRUD |
| `JWT` | `Core/Security/JWT.swift` | Core | Token decoding + expiry check |
| `UserService` | `Core/User/UserService.swift` | Core | Current user fetch |
| `AuthViewModel` | `Features/Authentication/ViewModels/AuthViewModel.swift` | Feature | Auth flow orchestration |
