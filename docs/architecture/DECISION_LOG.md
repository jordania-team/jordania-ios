# Decision Log

**Purpose:** Immutable record of architectural decisions made for the Jordania iOS project. Each entry captures the context, the options considered, and the decision taken. Entries are never edited after they are accepted — superseded decisions are closed with a reference to the decision that replaced them.

**Scope:** Architectural decisions only. Style and convention decisions live in [SWIFT_STYLE_GUIDE.md](../ios/SWIFT_STYLE_GUIDE.md). Mandatory rules derived from these decisions live in [ENGINEERING_RULES.md](ENGINEERING_RULES.md).

---

## How to Add an Entry

1. Copy the template below.
2. Assign the next sequential ID.
3. Set status to `Accepted`.
4. Never modify an accepted entry. If the decision changes, add a new entry with status `Supersedes ADR-NNN`.

```
### ADR-NNN — Title
**Date:** YYYY-MM-DD  
**Status:** Accepted

**Context:**
[Why this decision was needed.]

**Decision:**
[What was decided.]

**Consequences:**
[What becomes easier, what becomes harder, what is now forbidden.]
```

---

## Log

### ADR-001 — Feature-Based Folder Organisation
**Date:** 2026-05-31  
**Status:** Accepted

**Context:**
The project needed a folder structure that scales with new features without creating cross-cutting `Models/`, `Services/`, or `ViewModels/` folders at the root level. Layer-based organisation makes it easy to add types in the wrong layer and creates implicit coupling between features.

**Decision:**
Organise code by feature. Each feature folder is a vertical slice containing its own Views, ViewModels, and models. Cross-cutting infrastructure lives in `Core/`. Reusable UI lives in `Shared/`. Application-level orchestration lives in `App/`.

**Consequences:**
- Adding a new feature means creating one new folder, not scattering types across multiple folders.
- A global `Models/` folder is forbidden.
- Features must never import each other; shared code must be promoted to `Core/`.

---

### ADR-002 — AppContainer as Single Composition Root
**Date:** 2026-05-31  
**Status:** Accepted

**Context:**
Dependency injection requires a single place where concrete types are wired together. Without a defined composition root, injection points proliferate and the wiring becomes implicit and fragile.

**Decision:**
`AppContainer` is the sole composition root. It is instantiated once in `JordaniaTeamApp` and passed down through `RootView` and `MainTabView`. All dependencies are wired in `AppContainer.init`. Third-party SDK configuration is isolated in `AppContainer.bootstrap()` to keep `init` pure.

**Consequences:**
- The entire dependency graph is visible in one file.
- No Service Locator, no `shared` singletons (except the system `URLSession.shared` passed as a default).
- Testing a service in isolation requires only constructing it with explicit dependencies — no container setup.

---

### ADR-003 — Initialiser-Only Dependency Injection
**Date:** 2026-05-31  
**Status:** Accepted

**Context:**
DI frameworks (Swinject, Needle) add build-time complexity, require learning framework-specific patterns, and are unnecessary for a project of this size. Service Locators hide dependencies and make code harder to reason about.

**Decision:**
All dependencies are injected through `init` parameters. Protocols are not required for DI — concrete types are injected directly. Protocols are introduced only when a genuine abstraction boundary exists (e.g., a type that will have multiple implementations).

**Consequences:**
- No DI framework dependency.
- No Service Locator.
- Every type's dependencies are fully explicit from its `init` signature.
- Mocking in tests is achieved by constructing concrete types with test-controlled collaborators, not by swapping protocol implementations.

---

### ADR-004 — @Observable + @MainActor for All Observable State
**Date:** 2026-06-01  
**Status:** Accepted

**Context:**
Swift 5 `ObservableObject` with `@Published` has known performance issues (publishes before the change, not after) and requires `@StateObject`/`@ObservedObject` annotations at every consumer. Swift 6 introduces `@Observable` which is more efficient, integrates with `@State`, and aligns with the compiler's strict concurrency model.

**Decision:**
All observable types use `@Observable`. `ObservableObject`, `@Published`, and Combine are forbidden for new observable state. Observable types that drive UI are marked `@MainActor` to satisfy Swift 6 strict concurrency.

**Consequences:**
- ViewModels use `@State(initialValue:)` in their owning View, not `@StateObject`.
- `SessionStore` is `@Observable @MainActor`, making all state mutations automatically safe.
- No Combine import in any observable type.

---

### ADR-005 — Actor Isolation for APIClient and TokenProvider
**Date:** 2026-06-16  
**Status:** Accepted

**Context:**
Both `APIClient` and `TokenProvider` manage shared mutable state (`refreshTask` in `TokenProvider`) and are called concurrently from multiple features. Without actor isolation, concurrent refresh calls would race, potentially producing duplicate token requests or data races that Swift 6's strict concurrency would flag as errors.

**Decision:**
Both `APIClient` and `TokenProvider` are declared as `actor`. `TokenProvider` coalesces concurrent refresh requests via a stored `Task<String, Error>?`: if a refresh is in flight, subsequent callers await the same task rather than starting a new one.

**Consequences:**
- No data races on `refreshTask`.
- At most one refresh request is in flight at any time, regardless of how many features call `APIClient` concurrently.
- Callers of `APIClient.perform()` and `TokenProvider.validAccessToken()` must `await` — this is enforced by the Swift concurrency model.

---

### ADR-006 — JWTs Never Exposed in Observable Properties
**Date:** 2026-06-01  
**Status:** Accepted

**Context:**
If access tokens were stored as `@Observable` properties, they would be accessible to any View that holds a reference to `SessionStore`. This violates the principle of least privilege and creates an unnecessary attack surface.

**Decision:**
JWTs (access token and refresh token) are stored exclusively in the Keychain, accessed only by `SessionPersistence` and `TokenProvider`. `SessionStore` holds only `AuthenticatedUser` (no tokens) and `SessionState`. No View ever reads a token.

**Consequences:**
- Token values cannot leak through SwiftUI previews, logging, or debug dumps of observable state.
- `SessionStore.currentUser` is safe to read from any View — it contains no sensitive data.
- `APIClient` reads tokens from `TokenProvider`, which reads from `SessionPersistence`, which reads from `KeychainService` — the token never traverses the UI layer.

---

### ADR-007 — No Premature Modularisation
**Date:** 2026-06-01  
**Status:** Accepted

**Context:**
Swift Package Manager modularisation (splitting the app into multiple local packages) reduces build times and enforces boundaries in large teams. For a project of Jordania's current size and team, the build complexity overhead is not justified.

**Decision:**
The project is a single Xcode target. No local Swift packages are created. Boundaries are enforced by folder structure and code review, not by compiler module boundaries.

**Consequences:**
- Simpler build system.
- Boundary violations (a feature importing another feature) must be caught in review, not at compile time.
- This decision will be revisited if the team or codebase grows significantly (trigger: >5 features with >3 contributors per feature).

---

### ADR-008 — Session-First Routing via SessionState
**Date:** 2026-06-12  
**Status:** Accepted

**Context:**
The app needs to route between unauthenticated (`AuthView`), loading, error, and authenticated (`MainTabView`) states. Without a defined state machine, routing logic tends to spread across multiple views and conditions become implicit.

**Decision:**
`SessionState` is a Swift enum with four cases: `.loading`, `.authenticated`, `.signedOut`, `.error(String)`. `RootView` switches on this enum exclusively — it is the only place in the app that makes the top-level routing decision. All transitions go through `SessionStore`'s public action methods.

**Consequences:**
- The routing logic is in one place and is exhaustive — the compiler enforces that all cases are handled.
- New top-level states (e.g., `.onboarding`) require adding a case to `SessionState` and a branch in `RootView` — changes are localised.
- No view can route to `MainTabView` without going through `SessionStore.signIn()`.

---

### ADR-009 — AppConfiguration as a Caseless Enum for Environment Values
**Date:** 2026-07-04  
**Status:** Accepted

**Context:**
The application requires environment-specific configuration values — most critically the API base URL, which is `http://localhost:8080` in `DEBUG` builds and `https://api.redepets.xyz` in production. Several designs were considered: a singleton class, a `struct` with `static let` properties, a dependency injected into `AppContainer`, or a caseless `enum`.

A singleton class or struct introduces the risk of instantiation: nothing prevents `AppConfiguration()` from being created multiple times or stored as a dependency. Injecting configuration as a dependency into `AppContainer` adds indirection without benefit, since configuration values are compile-time constants resolved via `#if DEBUG`, not runtime values.

**Decision:**
`AppConfiguration` is a caseless `enum` with `static let` properties. A caseless enum cannot be instantiated — Swift's type system enforces that it is a namespace, not an object. The `apiBaseURL` property is resolved at compile time using `#if DEBUG`.

```swift
enum AppConfiguration {
    static let apiBaseURL: URL = {
        #if DEBUG
        URL(string: "http://localhost:8080")!
        #else
        URL(string: "https://api.redepets.xyz")!
        #endif
    }()
}
```

**Consequences:**
- `AppConfiguration` is a pure compile-time namespace. It cannot be instantiated, subclassed, or injected — eliminating an entire class of misuse.
- Adding a new environment value requires one `static let` property. No constructor changes, no DI wiring.
- The `#if DEBUG` flag is the single authority for environment switching. No `.xcconfig` gymnastics, no environment variables, no scheme arguments for this purpose.
- Values resolved via `#if DEBUG` are compiler-verified. A missing `#else` branch is a compile error, not a runtime crash.
- This pattern is appropriate only for compile-time constants. Runtime-variable configuration (e.g., feature flags fetched from a server) must not use this type.

---

### ADR-010 — Selective Protocols for Testability at Actor Boundaries
**Date:** 2026-07-04  
**Status:** Accepted

**Context:**
ADR-003 establishes that protocols are introduced only when a genuine abstraction boundary exists. Two such boundaries were identified during Phase 1:

1. **`SessionPersistenceProtocol`** — `TokenProvider` (an `actor`) depends on `SessionPersistence` (synchronous Keychain access). In test targets, Keychain access requires the `com.apple.security.keychain-access-groups` entitlement, which is not available in the Swift Testing runner. Without a protocol, `TokenProvider` cannot be tested without real Keychain entitlements.

2. **`BackendAuthServiceProtocol`** — `TokenProvider` calls `BackendAuthService.refresh()` to obtain new tokens. `BackendAuthService` performs live network requests. Without a protocol, testing `TokenProvider`'s refresh-coalescing logic requires a live backend.

In both cases, the protocol does not introduce a design abstraction — it introduces a **seam** that allows the dependency to be replaced with a test double that has no external requirements.

**Decision:**
Introduce minimal `Sendable` protocols for dependencies of actors that would otherwise require external infrastructure (Keychain entitlements, live network) in tests:

- `SessionPersistenceProtocol` — `nonisolated` + `Sendable`. Conformed to by `SessionPersistence` via a retroactive extension.
- `BackendAuthServiceProtocol` — `Sendable`. Conformed to by `BackendAuthService` via a retroactive extension.

`TokenProvider` is injected with `any SessionPersistenceProtocol` and `any BackendAuthServiceProtocol`. `AppContainer` passes the concrete types. Tests pass lightweight in-memory doubles.

No other types receive protocol wrappers under this ADR. The trigger for introducing a new protocol under this rule is: *the concrete type requires external infrastructure (entitlements, network, filesystem) that is unavailable in the test runner*.

**Consequences:**
- `TokenProvider`'s refresh-coalescing logic can be tested in full isolation: no Keychain, no network.
- The protocol surface is minimal — only the methods actually called by `TokenProvider` are in the contract.
- `AppContainer` still wires concrete types; the protocol is invisible at the composition root except in the type annotation.
- Adding a protocol for any other reason ("might need a mock someday", "cleaner design") is explicitly forbidden by ADR-003. The infrastructure-requirement trigger is the only valid justification.
- `nonisolated` on `SessionPersistenceProtocol` allows the actor (`TokenProvider`) to call its methods without crossing isolation boundaries, since the Keychain operations are synchronous and do not mutate actor state.
