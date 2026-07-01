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

- `KeychainService` — Keychain APIs are not available in unit test sandboxes without entitlements. Test through `SessionPersistence` with a fake `KeychainService` or use integration tests on a real device.
- `AppleAuthService` and `GoogleAuthService` — both depend on OS-level authentication dialogs. Test the logic that processes their output (the `AuthViewModel.performSignIn` path) by injecting a mock service.
- Views — layout is verified through Previews, not automated tests. Do not write `ViewInspector`-style tests.
- `AppContainer` — it is a composition root, not logic. There is nothing to assert.

---

## Testing Concurrency

Because `TokenProvider` and `APIClient` are `actor` types, and `SessionStore` and `AuthViewModel` are `@MainActor`, tests require correct actor context.

```swift
// Testing a @MainActor type
@Test @MainActor func authViewModel_signIn_setsLoading() async {
    ...
}

// Testing an actor method
@Test func tokenProvider_coalesces_concurrentRefreshes() async throws {
    let provider = TokenProvider(...)
    async let first = provider.forceRefresh()
    async let second = provider.forceRefresh()
    let results = try await [first, second]
    // Only one network call was made
    #expect(mockAuthService.refreshCallCount == 1)
}
```

Never use `Task.sleep` to sequence concurrent tests. Inject a controllable clock or use continuation-based mocks to control timing deterministically.

---

## Mocking Strategy

Jordania uses **protocol-free mocking via initialiser injection**. Dependencies are injected as concrete types through `init`, so test doubles are created by passing fake implementations directly.

Because `AppContainer.init` accepts a `persistence: SessionPersistence` parameter and `SessionPersistence.init` accepts a `keychain: KeychainService`, the entire persistence stack can be replaced in tests without protocols:

```swift
// Replace KeychainService with an in-memory double
let fakeKeychain = InMemoryKeychainService()
let persistence = SessionPersistence(keychain: fakeKeychain)
let store = SessionStore(persistence: persistence)
```

For service-level doubles (e.g., `BackendAuthService`), use a local `struct` inside the test file that matches the same interface:

```swift
struct AlwaysSucceedingAuthService: BackendAuthServiceProtocol {
    func login(...) async throws -> AuthSession { ... }
    func refresh(...) async throws -> AuthSession { ... }
}
```

If a protocol is needed to enable mocking, it is acceptable to introduce one locally in the test target — it does not need to live in production code.

---

## Test Organisation

```
JordaniaTeamTests/
├── Core/
│   ├── Authentication/
│   │   ├── TokenProviderTests.swift
│   │   └── BackendAuthServiceTests.swift
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
