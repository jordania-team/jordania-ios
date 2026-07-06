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
7. [Integration Tests](#integration-tests)
8. [Naming Convention](#naming-convention)

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

### Auth edge cases now covered

The authentication test suite must cover both business outcome and task-lifecycle behavior:

- Success path: session is created and no UI error is shown.
- User cancellation: `AuthError.cancelled` and `NetworkError.cancelled` remain silent.
- Typed network failure: `errorMessage` is populated from `NetworkError.errorDescription`.
- Duplicate submission: a second tap while the first sign-in task is active is ignored.
- Mid-flight loading: `isLoading` must be `true` while the async provider operation is still suspended, then `false` after teardown.

These cases exist because auth is both a domain boundary and a concurrency boundary. Regressions here are usually not syntax bugs — they are state-machine bugs.

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

### Testing @MainActor ViewModels with internal Task creation

A synchronous action method like `signInWithGoogle()` may create a `Task` and return immediately. In that case, assertions made immediately after the call may run before the task body has executed.

Canonical pattern:

1. Call the action.
2. `await Task.yield()` to let the scheduled work begin.
3. Assert intermediate state.
4. Resume the controlled dependency.
5. Yield again until teardown finishes.

This pattern is used in `AuthViewModelTests` to prove:
- loading starts before the provider flow completes,
- loading ends on every exit path,
- duplicate taps are ignored while `signInTask != nil`.

---

## Mocking Strategy

Jordania uses **initialiser injection first**. The default rule is still to inject concrete types directly and avoid protocol proliferation when there is no real abstraction boundary.

That said, Swift 6 strict concurrency and OS-owned authentication SDKs introduced one deliberate exception: **tiny capability protocols are acceptable when they are required to make a UI-adjacent async workflow testable without the real SDK**.

### Default approach

Prefer replacing collaborators through concrete test-controlled types passed into `init`:

```swift
let fakeKeychain = InMemoryKeychainService()
let persistence = SessionPersistence(keychain: fakeKeychain)
let store = SessionStore(persistence: persistence)
```

Use this approach when:
- The dependency is project-owned.
- The dependency can be instantiated safely in tests.
- The dependency does not require OS UI or third-party SDK presentation.

### Allowed exception: minimal service protocols

For `AuthViewModel`, the production code exposes two narrow protocols:

- `AppleAuthServicing`
- `GoogleAuthServicing`

These protocols do **not** exist to create a broad architectural abstraction. They exist for one reason only: the real Apple and Google auth services depend on OS- and SDK-driven flows that unit tests cannot drive directly.

The rule is:

- Introduce a protocol only at the seam that is impossible or expensive to test with the concrete type.
- Keep the protocol surface minimal — only the methods the consumer actually needs.
- Do not create "-able" protocols pre-emptively for every service in the codebase.

This keeps the architecture concrete-by-default while still allowing deterministic tests for authentication state transitions.

### Continuation-based mocks for async state validation

When a `@MainActor` ViewModel creates an internal `Task`, synchronous assertions immediately after calling the method are often observing state **before the task has started running**.

For these cases, use a continuation-based mock:

```swift
@MainActor
final class MockGoogleAuthService: GoogleAuthServicing {
    var stubbedResult: Result<AuthSession, Error>?
    private var continuation: CheckedContinuation<AuthSession, Error>?

    func signIn() async throws -> AuthSession {
        if let stubbedResult {
            return try stubbedResult.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func signOut() { }

    func resume(with result: Result<AuthSession, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
```

This pattern is used when the test needs to prove intermediate state such as:

- `isLoading == true` while sign-in is still in flight.
- Duplicate taps are ignored while the first task is still active.

The test flow is:

1. Inject a mock whose async method suspends via continuation.
2. Trigger the ViewModel action.
3. `await Task.yield()` so the internal task starts on the `@MainActor`.
4. Assert intermediate state.
5. Resume the continuation with success or failure.
6. Yield again until teardown completes, then assert final state.

### Why not `Task.sleep`?

`Task.sleep` is not used to sequence concurrent behavior because it is time-based and makes tests flaky. The project prefers:
- actor-aware control flow,
- explicit continuations,
- and `Task.yield()` only to give the executor a chance to run already-scheduled work.

### Why not test AppleAuthService or GoogleAuthService directly?

These types depend on OS-level or SDK-owned authentication surfaces:
- `AuthenticationServices`
- `GoogleSignIn`
- foreground `UIViewController` presentation

Those are integration boundaries, not stable unit-test seams. The unit tests therefore validate the consumer (`AuthViewModel`) and its state machine behavior instead of trying to automate provider SDK dialogs.

### Practical summary

- **Concrete injection by default**
- **Minimal protocol seam only when the concrete dependency is not unit-testable**
- **Continuation-based mocks for deterministic async state assertions**
- **No expectation-style blocking, no sleep-based timing control**

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

JordaniaTeamIntegrationTests/
├── Authentication/
│   └── BackendAuthServiceIntegrationTests.swift
├── Session/
│   ├── SessionPersistenceIntegrationTests.swift
│   └── SessionStoreIntegrationTests.swift
└── Helpers/
    ├── AuthFixtures.swift
    ├── InMemoryKeychainService.swift
    ├── MockURLProtocol.swift
    └── TestURLSessionFactory.swift
```

Mirror the source structure. One test file per source file under test, except where a production type is intentionally validated through a higher-value boundary.

`AppleAuthService` and `GoogleAuthService` are examples of this exception: their provider-SDK specifics are not unit-tested directly; the important behavior is verified through `AuthViewModelTests`.

---

## Integration Tests

Integration tests live in the `JordaniaTeamIntegrationTests` target, separate from unit tests. They are included in the default scheme (`cmd+U`) and run alongside unit tests.

### What integration tests prove

Where unit tests isolate a single type with all dependencies mocked, integration tests verify that **two or more real components collaborate correctly**. The boundary is defined by what is real vs. what is simulated:

| Suite | Real components | Simulated boundary |
|---|---|---|
| `BackendAuthService Integration` | `BackendAuthService`, `URLSession`, JSON decoding | HTTP responses via `MockURLProtocol` |
| `SessionPersistence Integration` | `SessionPersistence`, `InMemoryKeychainService`, JWT expiry logic | Keychain (replaced with in-memory equivalent) |
| `SessionStore Integration` | `SessionStore`, `SessionPersistence`, `InMemoryKeychainService` | Keychain, network |

### HTTP interception with MockURLProtocol

Network calls are intercepted by `MockURLProtocol`, a custom `URLProtocol` subclass registered on a dedicated `URLSession.ephemeral` instance. This session is injected into `BackendAuthService` via `init(session:)` — production code uses `URLSession.shared` by default.

```swift
// Production: uses URLSession.shared automatically
let service = BackendAuthService()

// Integration test: intercepts all requests
let service = BackendAuthService(session: TestURLSessionFactory.make())
```

`MockURLProtocol.requestHandler` is a `static var`. Because it is shared across all tests, suites that set this handler must be annotated with `@Suite(.serialized)` to prevent parallel tests from reading each other's handlers.

### Fixtures

All response payloads are defined in `AuthFixtures.swift`:

```swift
AuthFixtures.successResponse(for: url)        // 200 + valid AuthSessionResponse JSON
AuthFixtures.unauthorizedResponse(for: url)   // 401 + {"error": "Unauthorized"}
AuthFixtures.serverErrorResponse(for: url)    // 500 + {"error": "Internal Server Error"}
AuthFixtures.invalidPayloadResponse(for: url) // 200 + JSON missing required keys
```

### When to add integration tests

Add an integration test when:
- A new service makes HTTP calls and has non-trivial request construction or response decoding.
- A persistence layer combines multiple collaborators whose interaction is not covered by unit tests.
- A regression was caused by a contract mismatch between two real components.

Do **not** add integration tests for:
- Pure logic with no external collaborators (use unit tests).
- UI flows (use Previews or manual testing).
- The real backend (out of scope for this target).

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
