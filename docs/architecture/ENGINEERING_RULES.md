# Engineering Rules

**Purpose:** Non-negotiable constraints that every contributor must follow. The single authoritative list of what is forbidden and what is required in this codebase.

**Scope:** Mandatory rules only. Guidelines and style preferences live in `ios/`. Broader rationale for these decisions lives in [PROJECT_PHILOSOPHY.md](../PROJECT_PHILOSOPHY.md). Specific decision history lives in [DECISION_LOG.md](DECISION_LOG.md).

---

## Table of Contents

1. [Platform Baseline](#platform-baseline)
2. [Code Organisation](#code-organisation)
3. [Dependency Injection](#dependency-injection)
4. [Concurrency](#concurrency)
5. [Data Ownership](#data-ownership)
6. [Forbidden Patterns](#forbidden-patterns)

---

## Platform Baseline

The project targets **Swift 6** and **iOS 26+** exclusively. There is no compatibility floor below this.

- **Never introduce `#available` guards** unless an Apple API explicitly requires it for a new iOS 26 feature. Guarding for older OS versions is forbidden.
- **Never write backward-compatible code.** If a new API ships in iOS 26, use it unconditionally.
- **Always use the latest stable Xcode and iOS SDK.** No pinning to older toolchain versions.
- **Swift 6 strict concurrency is always on.** Zero data-race warnings are a build requirement, not a goal.
- `@Observable` is the only observation mechanism. `ObservableObject`, `@Published`, and Combine are forbidden for new code.
- Structured concurrency (`async`/`await`, `Task`, `TaskGroup`) is the only concurrency model. Callbacks, completion handlers, and `DispatchQueue` are forbidden for new code.

---

## Code Organisation

File placement is determined by feature ownership, not by type.

| What | Where | Rationale |
|---|---|---|
| App entry point, `AppContainer`, `RootView`, `MainTabView` | `App/` | Application-level concerns belong at the app layer |
| Session models (`AuthenticatedUser`, `SessionStore`, `SessionState`, `SessionPersistence`) | `Core/Session/` | Session is cross-cutting; it belongs in Core, not in any feature |
| Auth services (`AppleAuthService`, `GoogleAuthService`, `BackendAuthService`, `TokenProvider`) | `Core/Authentication/` | Auth infrastructure is cross-cutting |
| Networking (`APIClient`, `NetworkError`) | `Core/Networking/` | Shared infrastructure |
| Security (`KeychainService`, `JWT`) | `Core/Security/` | Shared infrastructure |
| Feature-specific ViewModels and Views | `Features/<FeatureName>/ViewModels/` and `Features/<FeatureName>/Views/` | Models and ViewModels belong to the feature that owns them |
| Reusable UI components and design tokens | `Shared/` | UI-only; contains no business logic |

**Violation examples:**
- A `Models/` folder at the project root → **forbidden**.
- A ViewModel placed in `Shared/` → **forbidden**.
- A feature-specific model placed in `Core/` → **forbidden** unless it is genuinely cross-cutting.

---

## Dependency Injection

- **Initialiser injection is the only permitted DI mechanism.** Dependencies are always passed through `init` parameters.
- **`AppContainer` is the single composition root.** It is instantiated once in `JordaniaTeamApp` and never recreated.
- **No Service Locator.** No global accessor, no `shared` singleton, no environment-based registry (except `@Environment` for SwiftUI system values).
- **No DI framework.** No Swinject, Needle, or equivalent.
- **`AppContainer` receives `SessionStore` by reference** — downstream types hold `weak var sessionStore: SessionStore?` to avoid retain cycles.
- Protocols are not required for DI. Concrete types are injected directly. Protocols are introduced only when a genuine abstraction boundary exists, not to enable injection.

See [DEPENDENCY_INJECTION.md](../ios/DEPENDENCY_INJECTION.md) for the full pattern reference.

---

## Concurrency

- **`@MainActor` is required on `SessionStore` and `AppContainer`.** All state mutations that drive the UI must run on the main actor.
- **`actor` isolation is required for `APIClient` and `TokenProvider`.** These types manage shared mutable state (the in-flight refresh task) and must be actors.
- **`Task { }` in a `@MainActor` context inherits the main actor.** No explicit `await MainActor.run { }` is needed inside Views or `@MainActor` classes.
- **Never block the main actor.** All network calls and Keychain I/O go through `async` methods.
- **`Sendable` conformance must be explicit** on any type that crosses actor boundaries. No `@unchecked Sendable` without a documented justification.
- **Cancellation is always handled.** `Task` cancellation and `AuthError.cancelled` / `NetworkError.cancelled` are caught silently — they never produce UI error messages.

---

## Data Ownership

- **`SessionStore` is the single source of truth for authentication state.** No other type stores a copy of `SessionState` or `AuthenticatedUser` that it mutates independently.
- **JWTs are never stored in observable properties.** Access tokens and refresh tokens live exclusively in the Keychain, accessed only by `SessionPersistence` and `TokenProvider`. The UI never reads a token.
- **State flows in one direction:** `AppContainer` composes → `SessionStore` owns state → `RootView` reads state → Views reflect state. Mutations travel back up only through explicit action methods (`signIn`, `signOut`, `validateSession`).
- **DTOs are private to their service file.** A `UserMeResponse` struct is `private` inside `UserService.swift`. It is never exported or reused outside its file.

---

## Forbidden Patterns

| Pattern | Reason |
|---|---|
| Global singletons (other than `AppContainer` via `@main`) | Untestable, hidden coupling |
| `UserDefaults` for any sensitive data | Not encrypted; use Keychain |
| Force unwrap (`!`) in production code | Crashes instead of recoverable errors; use `guard`/`if let` |
| `ObservableObject` / `@Published` / Combine | Superseded by `@Observable` (Swift 6) |
| Callbacks and completion handlers | Superseded by `async`/`await` |
| `DispatchQueue` for concurrency | Use `actor` or structured concurrency |
| Premature modularisation into Swift packages | No business case yet; increases build complexity for no gain |
| Feature code importing another feature | Features are independent; shared code lives in `Core/` or `Shared/` |
| View importing a service directly | Views interact only with their ViewModel |
| Service Locator / global container lookup | See [Dependency Injection](#dependency-injection) |
| `#available` guards for iOS < 26 | Platform baseline is iOS 26; older versions are not supported |
