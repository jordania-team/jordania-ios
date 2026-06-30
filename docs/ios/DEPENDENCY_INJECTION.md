# Dependency Injection

**Purpose:** Documents how Jordania manages dependencies — how the graph is constructed, how types receive their dependencies, and the rules that keep it explicit and testable.

**Scope:** Composition root, injection patterns, and rules. The reason these choices were made is recorded in [ADR-003](../architecture/DECISION_LOG.md#adr-003). Architecture layers are described in [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Table of Contents

1. [Principles](#principles)
2. [AppContainer — The Composition Root](#appcontainer--the-composition-root)
3. [Injection Patterns](#injection-patterns)
4. [Dependency Rules](#dependency-rules)
5. [Testing without Protocols](#testing-without-protocols)

---

## Principles

1. **Initialisers are the only injection mechanism.** Types declare their dependencies as init parameters. No property injection, no setter injection, no ambient globals.
2. **One composition root.** `AppContainer` is instantiated once by `JordaniaTeamApp` and is the sole place the dependency graph is assembled.
3. **No framework.** Swinject, Needle, Factory, and equivalents are not used. Plain Swift is sufficient.
4. **No Service Locator.** Types do not look up their dependencies from a global registry. They receive exactly what they need at init time and nothing more.
5. **SwiftUI environment for `SessionStore` only.** `SessionStore` is propagated via `.environment()` to make it accessible deep in the view tree without threading it through every intermediate view. This is the exception, not the model.

---

## AppContainer — The Composition Root

`AppContainer` builds the entire graph in its `init`. The construction order is determined by the dependency relationships:

```
SessionPersistence
  └── SessionStore
        └── AuthViewModel

SessionPersistence + BackendAuthService + SessionStore
  └── TokenProvider
        └── APIClient
              └── UserService
```

Full construction:

```swift
@MainActor
final class AppContainer {
    let sessionStore: SessionStore
    let apiClient: APIClient
    let authViewModel: AuthViewModel
    let userService: UserService

    init(
        persistence: SessionPersistence = SessionPersistence(),
        authService: BackendAuthService = BackendAuthService(),
        urlSession: URLSession = .shared
    ) {
        let store = SessionStore(persistence: persistence)
        let tokenProvider = TokenProvider(
            persistence: persistence,
            authService: authService,
            sessionStore: store
        )
        let client = APIClient(
            tokenProvider: tokenProvider,
            session: urlSession,
            sessionStore: store
        )
        self.sessionStore  = store
        self.apiClient     = client
        self.authViewModel = AuthViewModel(session: store)
        self.userService   = UserService(apiClient: client)
    }

    func bootstrap() {
        configureGoogleSignIn()
    }
}
```

The `init` accepts overrides for `SessionPersistence`, `BackendAuthService`, and `URLSession` — the three points that need to be substituted in tests or alternative configurations. All other types are constructed from these.

`bootstrap()` is called explicitly by `JordaniaTeamApp` after construction. This separation keeps `init` pure and free of side effects.

---

## Injection Patterns

### Pattern 1 — Direct ViewModel init (standard)

The most common pattern. `AppContainer` passes a dependency to a ViewModel at construction time:

```swift
// In AppContainer.init
self.authViewModel = AuthViewModel(session: store)
```

The ViewModel stores the dependency as a `private let`:

```swift
final class AuthViewModel {
    private let session: SessionStore
    private let appleAuthService: AppleAuthService
    private let googleAuthService: GoogleAuthService

    init(
        session: SessionStore,
        appleAuthService: AppleAuthService? = nil,
        googleAuthService: GoogleAuthService? = nil
    ) {
        self.session = session
        self.appleAuthService = appleAuthService ?? AppleAuthService()
        self.googleAuthService = googleAuthService ?? GoogleAuthService()
    }
}
```

Optional parameters with defaults are used for services that have no external dependencies and are easily substituted in tests (see [Testing without Protocols](#testing-without-protocols)).

### Pattern 2 — View-owned ViewModel init (when the View needs injected values)

When a View needs to construct its ViewModel with injected values from the call site, the ViewModel is created inside the View's `init` and owned via `@State`:

```swift
struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }
}
```

This ensures the ViewModel is created once, with the correct dependencies, before the View's first render.

### Pattern 3 — SwiftUI environment (SessionStore only)

`SessionStore` is injected into the SwiftUI environment at `RootView` so that views deep in the `AuthView` subtree can access it without threading it through every intermediate view:

```swift
// RootView.swift
case .signedOut:
    AuthView(session: container.sessionStore)
        .environment(container.sessionStore)
```

Child views read it with `@Environment(SessionStore.self)`. This pattern is **reserved for `SessionStore` only**. It must not be used for services, ViewModels, or `AppContainer`.

### Pattern 4 — Container propagation (for deep feature trees)

When a feature view tree needs multiple dependencies from `AppContainer`, the container is passed explicitly to the root of the tree:

```swift
// RootView.swift
case .authenticated:
    MainTabView(container: container)
```

`MainTabView` receives `container` and passes individual services to feature views that need them. No feature view imports or stores the full `AppContainer`.

---

## Dependency Rules

- **`AppContainer` is referenced only in `App/`.** `RootView` and `MainTabView` receive it; no feature ViewModel or service references `AppContainer` directly.
- **Services are `private let` properties of their consumers.** Dependencies are stored, not looked up.
- **No optional dependencies except at the `AppContainer` init boundary.** Internally, all dependencies are non-optional.
- **`weak var` for back-references that would create retain cycles.** `APIClient` and `TokenProvider` hold `weak var sessionStore: SessionStore?` to avoid a retain cycle through the graph.

---

## Testing without Protocols

Because the project does not add protocols for every service (see [ADR-005](../architecture/DECISION_LOG.md#adr-005)), tests substitute dependencies via:

1. **`AppContainer` init overrides** — pass a custom `URLSession` (e.g., one backed by `URLProtocol`) to intercept network calls.
2. **ViewModel optional init parameters** — `AuthViewModel` accepts optional `AppleAuthService` and `GoogleAuthService`, allowing lightweight subclasses or alternative initialisations.
3. **`@Observable` state observation** — test that `SessionStore.state` transitions correctly by calling `signIn` / `signOut` directly without mocking the Keychain.
4. **`SessionPersistence` init override** — pass a `KeychainService` subclass that stores in memory instead of the system Keychain during tests.
