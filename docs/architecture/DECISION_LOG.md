# Decision Log

**Purpose:** An append-only record of significant architectural decisions made for the Jordania iOS project. Each entry captures context, the options considered, the decision taken, and the consequences.

**Scope:** Architecture, technology choices, and engineering policy decisions. Implementation details belong in the document for the relevant subsystem.

> **Append-only.** Entries are never edited or deleted. Superseded decisions get a new entry referencing the old one.

---

## Table of Contents

- [ADR-001 — Feature-Based Architecture over Layer-Based](#adr-001)
- [ADR-002 — Lightweight MVVM without Use Cases or Repositories](#adr-002)
- [ADR-003 — No DI Framework; Plain Initialiser Injection via AppContainer](#adr-003)
- [ADR-004 — @Observable over ObservableObject](#adr-004)
- [ADR-005 — No Protocol Abstractions without a Real Second Conformer](#adr-005)
- [ADR-006 — Single APIClient Actor with Proactive + Reactive Token Refresh](#adr-006)
- [ADR-007 — Keychain as the Sole Storage for Tokens](#adr-007)
- [ADR-008 — No Premature Swift Package Modularisation](#adr-008)
- [ADR-009 — iOS 26+ Baseline; No Backward Compatibility Code](#adr-009)
- [ADR-010 — MainTabView lives in App/, not Features/](#adr-010)

---

## ADR-001
### Feature-Based Architecture over Layer-Based

**Date:** May 2026  
**Status:** Accepted

**Context:** An iOS social network for pets developed by a small team in an academy context. The team prioritises learning modern iOS engineering and maintainability over horizontal scalability.

**Options considered:**
1. Layer-based (`Models/`, `ViewModels/`, `Views/`, `Services/`)
2. Feature-based (`Features/Authentication/`, `Features/Feed/`, …)

**Decision:** Feature-based. Each feature owns its own Views, ViewModels, and models in a self-contained folder.

**Consequences:** New features can be developed and understood in isolation. Cross-feature dependencies are visible as folder-level imports and are structurally discouraged. The cost is that shared infrastructure must be explicitly placed in `Core/`, requiring deliberate decisions about what is truly cross-cutting.

---

## ADR-002
### Lightweight MVVM without Use Cases or Repositories

**Date:** May 2026  
**Status:** Accepted

**Context:** Academic project. Team is learning SwiftUI and wants to apply MVVM clearly without overengineering.

**Options considered:**
1. Full Clean Architecture (Use Cases, Repositories, Entities)
2. Lightweight MVVM (View + ViewModel + Service)

**Decision:** Lightweight MVVM. ViewModels dispatch directly to services. No intermediate Use Case or Repository layer.

**Consequences:** Less indirection, faster comprehension, easier to teach. The trade-off is that adding complex orchestration logic later may require refactoring ViewModels. Accepted: the project does not need enterprise-scale orchestration and premature abstraction is an explicit non-goal.

---

## ADR-003
### No DI Framework; Plain Initialiser Injection via AppContainer

**Date:** May 2026  
**Status:** Accepted

**Context:** Several iOS DI frameworks exist (Swinject, Needle, Factory). The project prioritises simplicity and explicit dependency graphs.

**Options considered:**
1. Third-party DI framework
2. Service Locator pattern
3. Plain Swift initialisers with a hand-written composition root

**Decision:** Plain Swift initialisers. `AppContainer` is the single composition root, constructed once at app launch.

**Consequences:** The dependency graph is fully explicit, type-safe, and visible in one file. No framework overhead, no generated code, no runtime registration. The cost is that `AppContainer` grows as the project grows — accepted for a single-target app at this scale.

---

## ADR-004
### @Observable over ObservableObject

**Date:** May 2026  
**Status:** Accepted

**Context:** iOS 17 introduced the `Observation` framework with `@Observable`, which supersedes `ObservableObject` + `@Published`.

**Decision:** All ViewModels and shared state objects use `@Observable`. `ObservableObject` and `@Published` are forbidden for new code.

**Consequences:** Fine-grained observation (only properties actually read by a View trigger re-renders), simpler syntax, better performance. Requires iOS 17+, which is below the iOS 26+ baseline.

---

## ADR-005
### No Protocol Abstractions without a Real Second Conformer

**Date:** June 2026  
**Status:** Accepted

**Context:** The team debated whether to wrap services (e.g., `BackendAuthService`, `UserService`) behind protocols to allow mocking in tests.

**Decision:** No protocol is introduced unless a real second conformer exists or is planned for the immediate next sprint. Mocking for tests is done via subclassing, parameter injection of lightweight structs, or by testing observable state changes directly.

**Consequences:** Less indirection, faster reading. The trade-off is that some unit tests require slightly more setup. Accepted: the project values simplicity over test infrastructure complexity.

---

## ADR-006
### Single APIClient Actor with Proactive + Reactive Token Refresh

**Date:** June 2026  
**Status:** Accepted

**Context:** Authenticated apps must handle token expiry gracefully. Common approaches include middleware interceptors, per-request retry logic, or a centralised token manager.

**Decision:** `APIClient` (an `actor`) handles the full refresh lifecycle: (1) proactive refresh via `TokenProvider.validAccessToken()` before every request, (2) reactive refresh via `forceRefresh()` on a 401, (3) terminal signout on a second 401. `TokenProvider` coalesces concurrent refresh requests.

**Consequences:** All token management is in two files (`APIClient.swift`, `TokenProvider.swift`). Services are unaware of authentication mechanics. The coalescing pattern prevents duplicate refresh calls under concurrent load. Maximum one network retry per request.

---

## ADR-007
### Keychain as the Sole Storage for Tokens

**Date:** May 2026  
**Status:** Accepted

**Context:** Tokens could be stored in `UserDefaults`, files, or the Keychain.

**Decision:** All tokens (access and refresh) are stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. `UserDefaults` is used only for non-sensitive, temporary data (e.g., Apple's one-time full name delivery).

**Consequences:** Tokens survive app reinstallation within the same device, are excluded from unencrypted backups, and are unavailable before first unlock. The `ThisDeviceOnly` flag prevents iCloud Keychain migration.

---

## ADR-008
### No Premature Swift Package Modularisation

**Date:** May 2026  
**Status:** Accepted

**Context:** Modularising into Swift packages provides build-time isolation and enforces boundaries but adds complexity.

**Decision:** The project is and remains a single target until a concrete need for modularisation emerges (e.g., a separate app extension that must share code).

**Consequences:** Simpler build setup, faster compile times for a small codebase. Folder conventions (`App/`, `Core/`, `Features/`, `Shared/`) enforce the same logical boundaries without the tooling overhead.

---

## ADR-009
### iOS 26+ Baseline; No Backward Compatibility Code

**Date:** May 2026  
**Status:** Accepted

**Context:** Supporting older iOS versions requires `#available` guards, deprecated 