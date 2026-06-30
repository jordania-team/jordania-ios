# Swift Style Guide

**Purpose:** Establishes the coding conventions for all Swift source files in the Jordania project. Consistent style reduces cognitive overhead when reading unfamiliar code.

**Scope:** Formatting, naming, access control, type annotations, and idiom preferences. Architecture and MVVM conventions belong in [MVVM_GUIDELINES.md](MVVM_GUIDELINES.md). Dependency injection conventions belong in [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md). Forbidden patterns are listed in [../architecture/ENGINEERING_RULES.md](../architecture/ENGINEERING_RULES.md).

---

## Table of Contents

1. [Formatting](#formatting)
2. [Naming](#naming)
3. [Access Control](#access-control)
4. [Types and Declarations](#types-and-declarations)
5. [Functions and Closures](#functions-and-closures)
6. [Error Handling](#error-handling)
7. [Comments and Documentation](#comments-and-documentation)
8. [SwiftUI Specifics](#swiftui-specifics)

---

## Formatting

- **Indentation:** 4 spaces. No tabs.
- **Line length:** Soft limit of 120 characters. Wrap long function signatures by aligning parameters under the first argument label.
- **Trailing whitespace:** Never. Xcode's default “Trim trailing whitespace” setting must be enabled.
- **Empty lines:** One empty line between `MARK` sections. No two consecutive empty lines.
- **Braces:** Opening brace on the same line. Closing brace on its own line.

```swift
// Correct
func signOut() {
    currentUser = nil
    state = .signedOut
}

// Wrong
func signOut()
{
    currentUser = nil
}
```

- **`MARK` sections:** Use `// MARK: - SectionName` to divide types into logical sections. Standard order:
  1. Nested types and enums
  2. Properties (stored, then computed)
  3. `init`
  4. Public / internal methods
  5. Private methods

```swift
// MARK: - Dependencies
private let persistence: SessionPersistence

// MARK: - Init
init(persistence: SessionPersistence) { … }

// MARK: - Actions
func signIn(user: AuthenticatedUser, …) { … }

// MARK: - Private
private func configureGoogleSignIn() { … }
```

---

## Naming

- **Types:** `UpperCamelCase`. Example: `AuthViewModel`, `SessionStore`, `NetworkError`.
- **Properties and methods:** `lowerCamelCase`. Example: `currentUser`, `isLoading`, `signOut()`.
- **Constants:** `lowerCamelCase`, not `SCREAMING_SNAKE_CASE`.
- **Enum cases:** `lowerCamelCase`. Example: `.authenticated`, `.signedOut`, `.loading`.
- **Boolean properties:** Use is/has/can/should prefix. Example: `isLoading`, `hasSession`.
- **Async functions:** Name the function after the result, not the operation. `fetchCurrentUser()` not `performUserFetch()`.
- **Error types:** Suffix with `Error`. Example: `AuthError`, `NetworkError`.
- **Services:** Suffix with `Service`. Example: `BackendAuthService`, `UserService`.
- **ViewModels:** Suffix with `ViewModel`. Example: `AuthViewModel`.
- **Views:** No suffix for feature root views. Example: `AuthView`, `FeedView`. Private subviews inside a file may use a descriptive suffix: `AppleSignInButton`.

### Avoid Noise

- Do not repeat the type name in property names: `sessionStore.currentUser` not `sessionStore.currentUserObject`.
- Do not prefix with the module name: `AuthError` not `JordaniaAuthError`.
- Do not use abbreviations unless universally understood (`URL`, `ID`, `JWT`). Never `mgr`, `svc`, `vm`.

---

## Access Control

- **Default to the most restrictive level.** Start with `private`, escalate only when needed.
- **`private(set)` for observable state.** Properties that external types should observe but not mutate must be `private(set)`:
  ```swift
  private(set) var currentUser: AuthenticatedUser?
  private(set) var state: SessionState = .loading
  ```
- **`internal` is the implicit default.** Only write it when needed for clarity.
- **`public` is never used.** The project is a single target with no public API surface.
- **`final` on all classes** unless inheritance is explicitly intended and documented.

---

## Types and Declarations

- **Prefer `struct` over `class`.** Use `class` only when identity semantics, `@Observable`, or a required deinit are needed.
- **Prefer `enum` with associated values over Bool flags.** `SessionState` is an enum, not `isAuthenticated: Bool` + `isLoading: Bool`.
- **Type inference over explicit annotation** when the type is obvious at the declaration site:
  ```swift
  // Preferred
  let store = SessionStore()
  var isLoading = false

  // Only when clarity demands it
  var state: SessionState = .loading
  ```
- **Avoid `Any` and `AnyObject`.** Use generics or protocols with associated types.
- **`guard` for early exits.** Use `guard let` / `guard else` at the top of a function to handle invalid states before the happy path.
- **No force unwrap (`!`) in production code.** Use `guard`, `if let`, or `try?`/`try` with proper error handling.

---

## Functions and Closures

- **Trailing closure syntax** when the last argument is a closure and its label adds no clarity:
  ```swift
  Task {
      await container.sessionStore.retry(using: container.userService)
  }
  ```
- **`defer` for cleanup** that must run on all exit paths (token refresh cleanup, loading state reset):
  ```swift
  defer {
      isLoading = false
      signInTask = nil
  }
  ```
- **Single-expression functions** may omit the `return` keyword.
- **`async throws` over completion handlers.** All asynchronous operations use structured concurrency.

---

## Error Handling

- **Always use typed errors** (`AuthError`, `NetworkError`). Never `throw NSError(…)`.
- **Handle cancellation silently.** `AuthError.cancelled` and `NetworkError.cancelled` must not produce UI error messages.
- **`do`/`catch` with explicit error types** in ViewModels when different errors require different user-facing messages:
  ```swift
  } catch AuthError.cancelled, NetworkError.cancelled {
      // silent
  } catch let networkError as NetworkError {
      errorMessage = networkError.errorDescription
  } catch {
      errorMessage = "Não foi possível concluir o login. Tente novamente."
  }
  ```
- **`errorDescription` is the user-facing message.** Never interpolate raw error descriptions into UI strings.

---

## Comments and Documentation

- **Doc comments (`///`) on all non-private types and non-trivial non-private methods.** Private helpers that are self-evident do not need comments.
- **Explain *why*, not *what*.** The code shows what; comments explain intent, constraints, and non-obvious decisions:
  ```swift
  /// A UI sempre desloga, mesmo se a limpeza do Keychain falhar.
  func signOut() { … }
  ```
- **Inline comments in Portuguese or English** are both acceptable. Be consistent within a file.
- **No commented-out code** in committed files.
- **`// MARK: -`** to separate sections (see Formatting).

---

## SwiftUI Specifics

- **`@State` for ViewModel ownership in Views.** Use `_viewModel = State(initialValue: …)` in the View's `init` when the ViewModel depends on an injected value:
  ```swift
  @State private var viewModel: AuthViewModel

  init(session: SessionStore) {
      _viewModel = State(initialValue: AuthViewModel(session: session))
  }
  ```
- **`@Environment` for `SessionStore` propagation.** `SessionStore` is injected into the SwiftUI environment at `AuthView` and read with `@Environment(SessionStore.self)` in child views that need it.
- **Extract private subviews** for reusable or environment-sensitive sub-components rather than embedding them inline. This is especially important when a subview reads `@Environment` values that must be read at render time, not at parent creation time.
- **Previews are required** for every View file. Previews serve as lightweight visual tests and living documentation.
- **No business logic in `body`.** The `body` property computes view trees. All logic — even simple formatting — belongs in a helper method or ViewModel.
