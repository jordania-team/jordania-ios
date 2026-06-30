# MVVM Guidelines

**Purpose:** Defines what "lightweight MVVM" means in Jordania and establishes the boundaries between Views, ViewModels, and services.

**Scope:** ViewModel responsibilities, View responsibilities, state management, and the patterns used in existing code. DI mechanics belong in [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md). Swift coding style belongs in [SWIFT_STYLE_GUIDE.md](SWIFT_STYLE_GUIDE.md). The broader architectural reasoning belongs in [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Table of Contents

1. [The Three Roles](#the-three-roles)
2. [ViewModel Rules](#viewmodel-rules)
3. [View Rules](#view-rules)
4. [State Ownership](#state-ownership)
5. [Async Action Pattern](#async-action-pattern)
6. [Error Presentation](#error-presentation)
7. [Anti-Patterns](#anti-patterns)

---

## The Three Roles

| Layer | Owns | Never does |
|---|---|---|
| **View** | Layout, animation, user interaction events | Business logic, direct service calls, state mutation |
| **ViewModel** | Observable state, action methods, service coordination | UI layout decisions, direct Keychain / network access |
| **Service** | Domain operations (network, persistence, SDK) | Observable state, UI concerns |

Lightweight MVVM has no Use Case layer and no Repository layer. ViewModels call services directly. This is a deliberate simplification — see [ADR-002](../architecture/DECISION_LOG.md#adr-002).

---

## ViewModel Rules

### Declaration

All ViewModels are `@Observable` `@MainActor` `final class`:

```swift
@Observable
@MainActor
final class AuthViewModel {
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let session: SessionStore
    private let appleAuthService: AppleAuthService
    private let googleAuthService: GoogleAuthService

    init(session: SessionStore, …) { … }
}
```

- **`@Observable`** — provides fine-grained observation; only properties actually accessed by a View trigger re-renders.
- **`@MainActor`** — all state mutations happen on the main thread; no explicit `DispatchQueue.main.async` needed.
- **`final class`** — `@Observable` requires a class; `final` prevents unintended subclassing.

### Responsibilities

- Expose **observable state** that the View renders: `isLoading`, `errorMessage`, domain data.
- Expose **action methods** that the View calls: `signInWithGoogle()`, `handleAppleSignIn(_:)`, `signOut()`.
- Coordinate service calls and update state based on results.
- Own the `Task` lifecycle for async operations.

### What ViewModels Must Not Do

- Import `SwiftUI` (exception: types that are part of the SwiftUI data model, e.g., `Color`).
- Read or write Keychain directly.
- Make `URLSession` calls directly.
- Contain layout or visual logic.
- Construct their own services — services are injected at init.

---

## View Rules

### ViewModel Ownership

Views own their ViewModel via `@State`. When the ViewModel requires an injected value, initialise it in the View's `init`:

```swift
struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }

    var body: some View { … }
}
```

This pattern ensures:
- The ViewModel is created once and survives view identity changes.
- The ViewModel receives its dependencies at creation time, not lazily.
- No ambient service lookup.

### View Responsibilities

- Read ViewModel properties and render them.
- Call ViewModel action methods in response to user interactions.
- Manage presentation state (`@State` booleans for sheet/alert visibility).
- Extract private subviews for visual organisation.

### What Views Must Not Do

- Contain `if`/`switch` logic that implements business rules.
- Call services, `SessionStore`, or `APIClient` directly.
- Own `Task` blocks that perform domain work (delegate to the ViewModel).

---

## State Ownership

| State type | Owner | Mechanism |
|---|---|---|
| Loading / error during an action | ViewModel | `var isLoading: Bool`, `var errorMessage: String?` |
| Authentication state | `SessionStore` | `@Observable` observed by `RootView` |
| Current user profile | `SessionStore.currentUser` | Propagated via `@Environment` or explicit passing |
| Navigation path (future) | Feature root ViewModel | `var path: NavigationPath` |
| Sheet / alert visibility | View | `@State var isSheetPresented: Bool` |

The rule: state that affects multiple views is owned by the highest common ancestor or by `SessionStore`. State local to one view is `@State` in that View.

---

## Async Action Pattern

`AuthViewModel.performSignIn(_:)` establishes the canonical pattern for async actions:

```swift
private func performSignIn(_ operation: @escaping () async throws -> AuthSession) {
    guard signInTask == nil else { return }   // prevent concurrent submissions
    isLoading = true
    signInTask = Task {
        defer {
            isLoading = false
            signInTask = nil
        }
        do {
            let authSession = try await operation()
            session.signIn(user: authSession.user,
                           accessToken: authSession.accessToken,
                           refreshToken: authSession.refreshToken)
        } catch AuthError.cancelled, NetworkError.cancelled {
            // silent — user-initiated cancellation
        } catch let networkError as NetworkError {
            errorMessage = networkError.errorDescription
        } catch {
            errorMessage = "Não foi possível concluir o login. Tente novamente."
        }
    }
}
```

Key properties of this pattern:
1. **Guard against concurrent execution** — `guard signInTask == nil` prevents double-submission.
2. **`defer` for teardown** — `isLoading` and `signInTask` are always reset, even on early exit.
3. **Typed cancellation handling** — `AuthError.cancelled` and `NetworkError.cancelled` are caught and discarded silently.
4. **Typed error handling** — known errors map to user-facing messages; unknown errors get a generic fallback.
5. **State update on `@MainActor`** — all mutations happen on the main actor without extra dispatching.

New async actions in other ViewModels must follow this same structure.

---

## Error Presentation

- ViewModels expose `var errorMessage: String?`.
- Views bind this to an `.alert` or inline error text.
- `nil` means no error is currently displayed.
- The ViewModel clears `errorMessage` before starting a new operation.
- **Never** show raw `Error.localizedDescription` — always use `error.errorDescription` from `LocalizedError` conformances, or a hardcoded fallback string.

---

## Anti-Patterns

| Anti-pattern | Problem | Correction |
|---|---|---|
| ViewModel imports `SwiftUI` for non-data reasons | Creates UI coupling | Move visual logic to the View |
| View calls `APIClient` or `KeychainService` directly | Bypasses ViewModel layer | Route through a ViewModel action |
| Multiple concurrent Tasks for the same action | Race conditions, duplicate state updates | Guard with a stored `Task?` property |
| `ObservableObject` / `@Published` | Superseded by `@Observable` | Migrate to `@Observable` |
| ViewModel constructed inside `body` | Recreated on every render | Own via `@State` in `init` |
| Business logic in `body` | Untestable, poor separation | Extract to ViewModel method |
