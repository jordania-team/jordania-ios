# Architecture

**Purpose:** Describes the overall structure of the Jordania iOS application — how layers are defined, how they communicate, and where each responsibility lives.

**Scope:** Layer definitions, data flow, composition root, and the reasoning behind the architectural choices. Navigation flow lives in [NAVIGATION.md](NAVIGATION.md). Folder layout lives in [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md). Dependency injection mechanics live in [../ios/DEPENDENCY_INJECTION.md](../ios/DEPENDENCY_INJECTION.md).

---

## Table of Contents

1. [Architectural Style](#architectural-style)
2. [Layers](#layers)
3. [Composition Root](#composition-root)
4. [Data Flow](#data-flow)
5. [Session Architecture](#session-architecture)
6. [Networking Architecture](#networking-architecture)
7. [Constraints](#constraints)

---

## Architectural Style

Jordania uses **Feature-Based Architecture with lightweight MVVM** inside each feature.

- The top-level folder structure organises code by feature (`Features/Authentication`, `Features/Feed`, …), not by layer (`Models/`, `ViewModels/`, `Services/`).
- Each feature owns its own Views, ViewModels, and models. Nothing is shared unless it is genuinely reusable across features.
- MVVM is "lightweight": ViewModels hold observable state and dispatch actions to services; they do not contain repositories, coordinators, or use-case objects. See [../ios/MVVM_GUIDELINES.md](../ios/MVVM_GUIDELINES.md).

---

## Layers

```
┌─────────────────────────────────────────────────────────┐
│  App/                                                   │
│  Entry point, composition root, root navigation         │
├─────────────────────────────────────────────────────────┤
│  Features/                                              │
│  Feature-scoped Views + ViewModels + models             │
├─────────────────────────────────────────────────────────┤
│  Core/                                                  │
│  Cross-cutting infrastructure: Session, Auth,           │
│  Networking, Security                                   │
├─────────────────────────────────────────────────────────┤
│  Shared/                                                │
│  Reusable SwiftUI components + DesignSystem tokens      │
└─────────────────────────────────────────────────────────┘
```

### App/
Owns the entry point (`JordaniaTeamApp`), the composition root (`AppContainer`), the root view (`RootView`), and the top-level tab controller (`MainTabView`). Nothing else belongs here.

### Features/
Each subdirectory is a self-contained feature. Features depend on `Core/` and `Shared/`; they never depend on other features.

### Core/
Cross-cutting infrastructure that multiple features need:
- `Authentication/` — provider services (Apple, Google), `BackendAuthService`, `TokenProvider`, `AuthError`
- `Networking/` — `APIClient`, `NetworkError`
- `Security/` — `KeychainService`, `JWT`
- `Session/` — `SessionStore`, `SessionPersistence`, `SessionState`, `AuthenticatedUser`
- `User/` — `UserService` (fetches the authenticated user profile from the backend)

### Shared/
Reusable SwiftUI components and design-system tokens available to all features. Contains no business logic, no models, no services. See [../design/COMPONENTS.md](../design/COMPONENTS.md).

---

## Composition Root

`AppContainer` is constructed once by `JordaniaTeamApp` and is the single place in the application where the dependency graph is assembled:

```swift
// AppContainer.swift — simplified
@MainActor
final class AppContainer {
    let sessionStore: SessionStore
    let apiClient: APIClient
    let authViewModel: AuthViewModel
    let userService: UserService

    init(...) {
        let store = SessionStore(persistence: persistence)
        let tokenProvider = TokenProvider(persistence: persistence,
                                          authService: authService,
                                          sessionStore: store)
        let client = APIClient(tokenProvider: tokenProvider,
                               session: urlSession,
                               sessionStore: store)
        self.sessionStore  = store
        self.apiClient     = client
        self.authViewModel = AuthViewModel(session: store)
        self.userService   = UserService(apiClient: client)
    }

    func bootstrap() { configureGoogleSignIn() }
}
```

The `init` is pure — it only wires types together. Side effects (SDK configuration) are deferred to `bootstrap()`, which is called explicitly by `JordaniaTeamApp`. This keeps the initialiser fast and testable.

---

## Data Flow

```
User action
    │
    ▼
View  ──calls──▶  ViewModel
                     │
                 dispatches
                     │
                     ▼
                 Service / APIClient
                     │
                 async throws
                     │
                     ▼
                 ViewModel updates @Observable state
                     │
                 SwiftUI observes
                     │
                     ▼
                 View re-renders
```

Rules:
- Views call ViewModel methods. They never call services or touch `SessionStore` directly.
- ViewModels call services. They never construct services — services are injected at init.
- Services mutate `SessionStore` only through its public API (`signIn`, `signOut`).
- `SessionStore` is the only type that persists or clears session state.

---

## Session Architecture

`SessionStore` is the observable source of truth for authentication state. It drives `RootView`'s navigation switch:

```
SessionState
  .loading        → ProgressView()
  .authenticated  → MainTabView(container:)
  .signedOut      → AuthView(session:)
  .error(message) → SessionErrorView(message:retry:)
```

`SessionStore` delegates all Keychain operations to `SessionPersistence`, which in turn delegates to `KeychainService`. `SessionStore` never imports `Security` directly and never reads a raw JWT.

The token lifecycle is managed by `TokenProvider` (an `actor`):
1. **Proactive refresh** — before any request, `validAccessToken()` checks if the token expires within 10 minutes and refreshes proactively.
2. **Reactive refresh** — if a 401 is received despite the proactive check, `APIClient` calls `forceRefresh()`.
3. **Coalescing** — concurrent refresh requests share a single `Task<String, Error>` to avoid duplicate network calls and race conditions.
4. **Terminal** — a second 401 after refresh triggers `signOut()` and throws `NetworkError.unauthorized`.

---

## Networking Architecture

`APIClient` is an `actor` with a single public method: `perform(_ request: URLRequest) async throws -> Data`. Services build plain `URLRequest` values and pass them to `APIClient`, which:

1. Obtains a valid token from `TokenProvider`.
2. Injects the `Authorization: Bearer <token>` header.
3. Executes the request.
4. Handles the proactive/reactive/terminal refresh cycle.

Services decode the returned `Data` themselves. `APIClient` knows nothing about response shapes.

---

## Constraints

- Features never import other features.
- `Shared/` never imports `Core/` or `Features/`.
- `AppContainer` is never referenced outside of `App/`.
- No global state outside of `AppContainer`'s owned graph.
- No premature modularisation into Swift packages.
