# Decision Log

**Purpose:** Record significant architectural and engineering decisions — what was decided, why, and what alternatives were considered.

**Format:** Each entry has a status (`Accepted`, `Superseded`, `Deprecated`), a date, and a summary of context, decision, and consequences.

---

## ADR-001 — Integration tests use real components with HTTP boundary mocked via URLProtocol

**Status:** Accepted  
**Date:** 2026-07-06

### Context

The project had 41 unit tests covering individual types in isolation. Unit tests mock all dependencies, which means they do not verify that components work correctly together. Three integration points were identified as high-risk:

1. `BackendAuthService` — constructs HTTP requests and decodes HTTP responses. A unit test can verify request construction or decoding in isolation, but not both in the same pass.
2. `SessionPersistence` — combines JWT expiry logic with Keychain reads and writes. The interaction between these two concerns is not covered by unit tests.
3. `SessionStore` — orchestrates `SessionPersistence` and state machine transitions. The cold-launch restore path depends on both components working together.

The question was: how far into the real stack should integration tests reach?

### Decision

Integration tests use **real production implementations** of all components under test, with the **HTTP network boundary** as the only simulated layer.

- HTTP is intercepted via `MockURLProtocol`, a `URLProtocol` subclass registered on a test-scoped `URLSession.ephemeral` instance.
- `BackendAuthService` accepts a `URLSession` via `init(session:)`. In production it defaults to `URLSession.shared`. In tests it receives the mock session.
- The real Keychain is replaced with `InMemoryKeychainService` — a conforming in-memory substitute — because the Keychain is a process-sandboxed OS resource, not an architectural boundary worth testing.
- No backend process is required. All test responses are defined in `AuthFixtures` as deterministic, in-process `(Data, HTTPURLResponse)` pairs.

### Alternatives considered

**Run against a real local backend.** Rejected: requires a running backend process, introduces flakiness from process lifecycle and database state, and cannot be run in CI without Docker. The value does not justify the infrastructure cost at this stage.

**Mock at the service protocol level (like unit tests).** Rejected: this is just a unit test with a different name. The goal was to exercise the real decoding and persistence logic, not to replace it with stubs.

**Use `WireMock` or a similar HTTP stubbing library.** Rejected: `URLProtocol` is the native Apple mechanism for this purpose and does not require a third-party dependency.

### Consequences

- Integration tests catch contract mismatches between components that unit tests would miss (e.g., `BackendAuthService` decoding a field name that changed, `SessionPersistence` writing a key that `SessionStore` reads under a different name).
- `MockURLProtocol.requestHandler` is a `static var`. Suites that set this handler must use `@Suite(.serialized)` to prevent test parallelism from causing handler leakage.
- The `JordaniaTeamIntegrationTests` target is included in the default scheme and runs on every `cmd+U`. This is intentional: integration tests are fast enough (< 10ms total) to run alongside unit tests without slowing the feedback loop.
- If a future feature requires testing against a real backend (e.g., end-to-end auth with a staging environment), a separate scheme and test target should be created — not this one.
