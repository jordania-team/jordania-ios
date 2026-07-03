# Testing

**Purpose:** Define the testing strategy for Jordania — what to test, how to test it, and what tooling to use.

**Scope:** Unit and integration tests for Core and Features. Does not cover UI snapshot testing or end-to-end testing against the real backend.

---

## Table of Contents

1. [Framework & Baseline](#framework--baseline)
2. [What to Test](#what-to-test)
3. [What Not to Test](#what-not-to-test)
4. [Testing Concurrency](#testing-concurrency)
5. [Mocking Strategy](#mocking-strategy)
6. [Test Organisation](#test-organisation)
7. [Naming Convention](#naming-convention)

---

## Framework & Baseline

Jordania uses **Swift Testing** exclusively. XCTest is not used for new tests.

```swift
import Testing

@Test func sessionStore_signIn_setsAuthenticatedState() async throws {
    ...
}
```

Baseline:
- Swift 6 strict concurrency is enforced in test targets.
- All tests are `async` by default — never use `XCTestExpectation` or `DispatchSemaphore`.
- Test targets mirror the module structure: one test file per source file under test.

---

## What to Test

### High-value targets

| Layer | What to cover |
|---|---|
| `SessionStore` | All `SessionState` transitions: `signIn`, `signOut`, `validateSession` success, `validateSession` 401, `validateSession` network failure (stays `.authenticated`) |
| `TokenProvider` | Proactive refresh (token near expiry), reactive refresh (forced after 401), coalescing (only one refresh task created under concurrent calls), terminal path (second 401 → `signOut`) |
| `APIClient` | Proactive path (valid token → 200), reactive path (401 → refresh → 200), terminal path (401 → refresh → 401 → `signOut`) |
| `JWT` | `isExpired` and `needsRefresh` with known tokens; boundary conditions at expiry window |
| `SessionPersistence` | `loadSession` discards expired access token and clears Keychain; valid session is returned intact |
| `AuthViewModel` | `isLoading` toggles correctly; `errorMessage` is set on `NetworkError`; cancellations are silent; duplicate taps are ignored |
| `NetworkError` | `URLError` mapping covers all declared cases |

### Error taxonomy

`AuthError` and `NetworkError` are separate error types with distinct semantics — both should be tested at the mapping boundaries where one converts to the other (e.g., `BackendAuthService.refresh` mapping `NetworkError.unauthorized` → `AuthError.sessionExpired`).

---

## What Not to Test

- **`KeychainService`** — Keychain APIs are not available in unit test sandboxes without entitlements. Test through `SessionPersistence` with a fake `KeychainService`.
- **`AppleAuthService` and `GoogleAuthService`** — both depend on OS-level authentication dialogs and system frameworks (`AuthenticationServices`, `GoogleSignIn`) that are not available in the test target sandbox. The strategy is to test the logic that consumes their output: `AuthViewModel.performSignIn` is covered by injecting `MockGoogleAuthService` via the `GoogleAuthServicing` protocol. See [Mocking Strategy](#mocking-strategy).
- **Views** — layout is verified through Previews, not automated tests. Do not write `ViewInspector`-style tests.
- **`AppContainer`** — it is a composition root, not logic. There is nothing to assert.

---

## Testing Concurrency

Because `TokenProvider` and `APIClient` are `actor` types, and `SessionStore` and `AuthViewModel` are `@MainActor`, tests require correct actor context.

```swift
// Testing a @MainActor type: annotate the entire @Suite
@Suite("AuthViewModel")
@MainActor
struct AuthViewModelTests { ... }

// Testing an actor method
@Test func tokenProvider_coalesces_concurrentRefreshes() async throws {
    let provider = TokenProvider(...)
    async let first = provider.forceRefresh()
    async let second = provider.forceRefresh()
    let results = try await [first, second]
    #expect(mockAuthService.refreshCallCount == 1)
}
```

### Deterministic timing with continuation-based mocks

Never use `Task.sleep` to sequence concurrent tests. Use continuation-based mocks to suspend a dependency until the test is ready to observe the intermediate state, then release it.

```swift
// Mock that blocks until resume() is called
@MainActor
final class MockGoogleAuthService: GoogleAuthServicing {
    var stubbedResult: Result<AuthSession, Error>?
    private var pendingContinuation: CheckedContinuation<AuthSession, Error>?

    func signIn() async throws -> AuthSession {
        if let stubbedResult { return try stubbedResult.get() }
        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    func resume(with result: Result<AuthSession, Error>) {
        pendingContinuation?.resume(with: result)
        pendingContinuation = nil
    }
}

// Usage: observe isLoading == true while the task is suspended
@Test func authViewModel_performSignIn_isLoadingTogglesAroundExecution() async {
    let google = MockGoogleAuthService()
    google.stubbedResult = nil               // blocking mode
    let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

    viewModel.signInWithGoogle()
    await Task.yield()                       // let the internal Task start

    #expect(viewModel.isLoading == true)

    google.resume(with: .success(stubSession()))
    for _ in 0..<10 {                        // drain until defer runs
        await Task.yield()
        if !viewModel.isLoading { break }
    }

    #expect(viewModel.isLoading == false)
}
```

**Why `Task.yield()` before the first assert:** `signInWithGoogle()` creates a `Task` but does not execute it. On `@MainActor`, the task is enqueued and only runs when the current caller yields. Without `await Task.yield()`, the task has not started yet — `isLoading` is still `false` and `signInCallCount` is still `0`.

---

## Mocking Strategy

Jordania uses **initialiser injection** as the primary DI mechanism. Protocols are introduced only when a genuine abstraction boundary exists. There are two distinct cases:

### Case 1 — Fake concrete types (preferred)

For types whose dependencies are all in-module, replace collaborators by constructing concrete fakes through `init`:

```swift
// Replace KeychainService with an in-memory double
let fakeKeychain = InMemoryKeychainService()
let persistence = SessionPersistence(keychain: fakeKeychain)
let store = SessionStore(persistence: persistence)
```

### Case 2 — Protocols required by framework boundary

When a concrete type depends on a system framework that is unavailable in the test target (e.g., `AuthenticationServices`, `GoogleSignIn`), a protocol is introduced in **production code** so the test target can inject a mock without importing the unavailable framework.

`AuthViewModel` is the canonical example:

```swift
// Defined in production (AuthViewModel.swift)
@MainActor
protocol GoogleAuthServicing: AnyObject {
    func signIn() async throws -> AuthSession
    func signOut()
}

// Concrete conformance in production
extension GoogleAuthService: GoogleAuthServicing {}

// Mock lives only in the test target
@MainActor
final class MockGoogleAuthService: GoogleAuthServicing { ... }
```

**The rule:** protocols live in production only when the test target cannot import the framework the concrete type depends on. This is not a general abstraction strategy — it is a targeted seam for untestable framework boundaries.

---

## Test Organisation

```
JordaniaTeamTests/
├── Core/
│   ├── Authentication/
│   │   └── TokenProviderTests.swift
│   ├── Networking/
│   │   ├── APIClientTests.swift
│   │   └── NetworkErrorTests.swift
│   └── Session/
│       ├── SessionStoreTests.swift
│       ├── SessionPersistenceTests.swift
│       └── JWTTests.swift
└── Features/
    └── Authentication/
        └── AuthViewModelTests.swift
```

Mirror the source structure. One test file per source file. Group related assertions inside a single `@Test` using `#expect` — avoid one assertion per test function.

---

## Naming Convention

```swift
@Test func <subject>_<condition>_<expectedResult>()
```

Examples:
- `sessionStore_validateSession_signOutOn401`
- `tokenProvider_forceRefresh_coalescesConcurrentCalls`
- `jwt_isExpired_returnsTrueWithinLeeway`
- `authViewModel_performSignIn_ignoresDuplicateTap`

Test names are read as sentences. They must be specific enough to diagnose a failure without opening the file.
