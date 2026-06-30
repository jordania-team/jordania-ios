# Engineering Rules

**Purpose:** The authoritative, non-negotiable list of constraints that every contributor must follow. These rules exist to keep the codebase consistent, safe, and maintainable.

**Scope:** Mandatory rules only — what is forbidden and what is required. Preferences and guidelines live in `ios/`. The reasoning behind each rule is here; broader context lives in [PROJECT_PHILOSOPHY.md](../PROJECT_PHILOSOPHY.md).

---

## Table of Contents

1. [Platform Baseline](#platform-baseline)
2. [Code Organisation](#code-organisation)
3. [Dependency Management](#dependency-management)
4. [Concurrency](#concurrency)
5. [Data Ownership](#data-ownership)
6. [Forbidden Patterns](#forbidden-patterns)

---

## Platform Baseline

- **Swift 6.** The project compiles with Swift 6 language mode. Strict concurrency checking is always enabled.
- **iOS 26+ deployment target.** No `#available` guards, no conditional API usage, no backward-compatibility shims — ever. If a new API requires iOS 26, use it unconditionally.
- **Latest stable Xcode and iOS SDK.** Always build against the newest released toolchain. Never pin to an older SDK to work around warnings.
- **`@Observable` is the only observation mechanism.** `ObservableObject`, `@Published`, and Combine observation are forbidden for new code.
- **`async`/`await` is the only concurrency model.** Completion handlers, `DispatchQueue`, `NotificationCenter` callbacks, and Combine pipelines are forbidden for new async work.

---

## Code Organisation

- **Feature models live inside their feature folder.** There is no global `Models/` directory. A model that belongs to a feature is co-located with that feature.
- **Session models live in `Core/Session/`.** `AuthenticatedUser`, `SessionState`, `SessionStore`, and `SessionPersistence` are the sole exception to the rule above — they are cross-cutting concerns owned by the core layer.
- **`Shared/` is UI-only.** Only reusable SwiftUI components and design-system tokens belong in `Shared/`. Business logic, services, and models must never be placed there.
- **`MainTabView` lives in `App/`.** It coordinates top-level navigation and is an application-layer concern, not a feature.
- **One type per file.** Each Swift file declares exactly one primary type. Nested private helpers inside the same file are acceptable.
- **File names match their primary type.** `AuthViewModel.swift` contains `AuthViewModel`. No exceptions.

---

## Dependency Management

- **All dependencies are injected through initialisers.** No property wrapper injection, no ambient context, no environment-based service lookup outside of SwiftUI's native `.environment()` for `SessionStore`.
- **`AppContainer` is the single composition root.** It is instantiated once by `JordaniaTeamApp` and propagated explicitly. Nothing else constructs the dependency graph.
- **No Service Locator.** A global registry that types call into to retrieve their dependencies is forbidden. Callers must not know about `AppContainer` — they receive only what they need.
- **No third-party DI framework.** Dependency injection is done with plain Swift initialisers. No Swinject, Needle, Factory, or equivalent.
- **No premature modularisation.** The project is a single target. Swift Package Manager modules are not introduced until a clear need emerges and is explicitly decided.
- **Third-party SDKs are isolated behind internal wrappers.** `GoogleAuthService` wraps the GoogleSignIn SDK. Feature code never imports `GoogleSignIn` directly.

---

## Concurrency

- **No data races.** The project compiles with strict concurrency enabled. Every type must be `Sendable` or isolated to an actor. Warnings are errors.
- **`@MainActor` on all `@Observable` ViewModels and `SessionStore`.** State that drives the UI must be updated on the main actor.
- **`actor` for shared mutable state accessed from multiple tasks.** `APIClient` and `TokenProvider` are actors. Any new type with shared mutable state that is accessed concurrently must also be an actor.
- **One refresh task at a time.** `TokenProvider` coalesces concurrent refresh requests via a stored `Task<String, Error>?`. This pattern must be preserved if `TokenProvider` is ever modified.
- **`Task` cancellation must be handled.** `AuthError.cancelled` and `NetworkError.cancelled` are silent — they must never produce a UI error message. Any new operation that can be cancelled must follow this convention.

---

## Data Ownership

- **`SessionStore` is the single source of truth for authentication state.** No other type stores a copy of the current user or the session state. Features observe `SessionStore.currentUser` and `SessionStore.state` directly.
- **JWTs are never exposed as observable properties.** The access token and refresh token live exclusively in the Keychain, accessed only through `SessionPersistence`. The UI layer never reads a token.
- **State mutations happen inside the owning type.** `SessionStore.signIn()` and `SessionStore.signOut()` are the only entry points for state changes. External callers do not mutate `currentUser` or `state` directly.
- **`private(set)` on all observable state.** Properties that should not be mutated from outside a type must be declared `private(set)`.

---

## Forbidden Patterns

| Pattern | Reason |
|---|---|
| `Singleton` (other than `AppContainer`) | Creates hidden dependencies and untestable code |
| Global mutable state | Violates strict concurrency; causes data races |
| Force unwrap (`!`) in production code | Use `guard`, `if let`, or throw |
| `ObservableObject` / `@Published` | Superseded by `@Observable` in Swift 5.9+ / iOS 17+ |
| Completion handlers for async work | Superseded by `async`/`await` |
| Combine pipelines for new code | `async`/`await` + `@Observable` replace all use cases |
| Protocol-per-concrete-type abstraction | Only add protocols when a real second conformer exists |
| `#available` version guards | Target is iOS 26+; guards are dead code |
| Business logic in Views | Views render state; logic lives in ViewModels or services |
| Models in `Shared/` | `Shared/` is UI-only |
