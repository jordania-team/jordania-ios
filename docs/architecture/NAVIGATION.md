# Navigation

**Purpose:** Document how Jordania routes between top-level destinations and how the authentication state machine drives that routing.

**Scope:** Application-level navigation only — `SessionState`, `RootView`, and `MainTabView`. Feature-internal navigation (sheet presentation, push navigation within a feature) is the responsibility of each feature and is not covered here. The architectural context for these types lives in [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Table of Contents

1. [Session State Machine](#session-state-machine)
2. [RootView — Top-Level Router](#rootview--top-level-router)
3. [MainTabView — Authenticated Navigation](#maintabview--authenticated-navigation)
4. [Lifecycle Events](#lifecycle-events)
5. [Adding a New Tab](#adding-a-new-tab)

---

## Session State Machine

`SessionState` is a Swift enum with four cases. `SessionStore.state` is the single observable source that drives all top-level routing decisions.

```
               app launch
                   │
                   ▼
             ┌─────────┐
             │ loading │  ← initial state while Keychain is read
             └────┬────┘
      ┌───────────┼────────────┐
      ▼           ▼            ▼
 ┌──────────┐ ┌──────────┐ ┌───────────────────────────┐
 │signedOut │ │authenticated│ │ error(String)            │
 └────┬─────┘ └─────┬────┘ └────────────┬──────────────┘
      │              │                   │
  user logs in    session             retry()
      │           expires                │
      └──────────────┴───────────────────┘
                   │
              (cycle)
```

| Case | Meaning | `RootView` renders |
|---|---|---|
| `.loading` | Keychain read in progress; session validity unknown | `ProgressView()` |
| `.authenticated` | Valid session in Keychain; user identity available via `currentUser` | `MainTabView` |
| `.signedOut` | No session, or session was explicitly cleared | `AuthView` |
| `.error(String)` | Session validation failed with a non-recoverable error | `SessionErrorView` |

**Transitions:**
- `loading → authenticated` or `loading → signedOut`: triggered during `SessionStore.init` based on `SessionPersistence.loadSession()`.
- `authenticated → signedOut`: triggered by `SessionStore.signOut()` — called explicitly by the user, or by `APIClient` after a second 401.
- `authenticated → error(String)`: triggered by `SessionStore.validateSession()` encountering an unexpected failure.
- `error → loading → authenticated/signedOut`: triggered by the retry action in `SessionErrorView`.

---

## RootView — Top-Level Router

`RootView` is a pure routing view. It reads `container.sessionStore.state` and switches between destinations. It contains no UI chrome of its own.

```swift
// RootView.swift — abridged for documentation
switch container.sessionStore.state {
case .loading:          ProgressView()
case .authenticated:    MainTabView(container: container)
case .signedOut:        AuthView(session: container.sessionStore)
                            .environment(container.sessionStore)
case .error(let msg):   SessionErrorView(message: msg) { retry }
}
```

**Design decisions:**
- `RootView` receives `AppContainer` directly. This is intentional — it is the handoff point between the composition root and the feature/navigation layer.
- `SessionStore` is passed as `@Environment` to `AuthView` so that deeply nested views can read session state without prop-drilling.
- `RootView` does not animate between states. State transitions at this level are infrequent and abrupt transitions (sign-in, sign-out) are acceptable.

---

## MainTabView — Authenticated Navigation

`MainTabView` is displayed when `SessionStore.state == .authenticated`. It owns the tab structure for the authenticated experience.

**Current tabs:**

| Tab | Label | SF Symbol | Role | View |
|---|---|---|---|---|
| 1 | Feed | `rectangle.stack.fill` | Standard | `FeedView()` |
| 2 | Map | `location.fill` | Standard | `MapView()` |
| 3 | Profile | `person.fill` | Standard | `ProfileView()` |
| 4 | Search | `magnifyingglass` | `.search` | `SearchView()` |

The Search tab uses `role: .search`, which enables the iOS 26 native search tab behaviour.

**Passing dependencies to tabs:**
`MainTabView` receives `AppContainer`. Individual feature Views receive only the specific dependencies they need (e.g., `FeedView` would receive a `FeedViewModel` or `APIClient` — not the entire container). This is an application of the principle of least knowledge.

**`MainTabView` lives in `App/`**, not in any feature folder, because the tab structure is an application-level concern. A change to which tabs exist is a change to the app, not to any one feature.

---

## Lifecycle Events

### App Launch
```
1. JordaniaTeamApp initialises AppContainer
2. SessionStore.init reads Keychain → sets initial state (.authenticated or .signedOut)
3. RootView renders based on initial state
4. .task fires: AppContainer.bootstrap() + SessionStore.validateSession()
5. validateSession() calls UserService.fetchCurrentUser()
   → Success: currentUser refreshed, state stays .authenticated
   → 401: signOut() called, state → .signedOut
   → Network failure: warning logged, state unchanged (offline tolerance)
```

### Returning to Foreground
```
.onChange(of: scenePhase) — triggers when phase == .active
  → SessionStore.validateSession()
  → Same outcomes as launch validation
```
This ensures stale sessions are caught when the user returns to the app after an extended background period.

### Sign Out
```
AuthViewModel.signOut()
  → GoogleAuthService.signOut() (if provider == .google)
  → SessionStore.signOut()
    → state = .signedOut (immediate, before Keychain clear)
    → KeychainService.clearAll() (best-effort; failure is logged, not shown to user)
  → RootView observes state change → renders AuthView
```

---

## Adding a New Tab

1. Create the feature folder under `Features/<NewFeature>/Views/`.
2. Implement `<NewFeature>View`.
3. Add a `Tab` entry to `MainTabView.body`.
4. Pass the required dependency from `AppContainer` to the new View.
5. If the new tab requires a new service, add it to `AppContainer.init`.

No changes to `RootView` or `SessionStore` are required to add a tab.
