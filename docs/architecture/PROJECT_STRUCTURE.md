# Project Structure

**Purpose:** Document the physical folder layout of the Jordania iOS project and the rules that govern where files are placed.

**Scope:** Folder organisation and file placement rules. Architectural layer responsibilities live in [ARCHITECTURE.md](ARCHITECTURE.md). Naming and code style conventions live in [SWIFT_STYLE_GUIDE.md](../ios/SWIFT_STYLE_GUIDE.md).

---

## Table of Contents

1. [Folder Map](#folder-map)
2. [Placement Rules](#placement-rules)
3. [Naming Conventions](#naming-conventions)
4. [What Lives Where — Quick Reference](#what-lives-where--quick-reference)

---

## Folder Map

```
JordaniaTeam/
├── App/
│   ├── AppConfiguration.swift       # Environment constants (apiBaseURL)
│   ├── AppContainer.swift           # Composition root
│   ├── JordaniaTeamApp.swift        # @main entry point
│   ├── MainTabView.swift            # Authenticated tab bar
│   └── RootView.swift               # Top-level navigation router
│
├── Core/
│   ├── Authentication/
│   │   ├── AppleAuthService.swift
│   │   ├── AuthError.swift
│   │   ├── BackendAuthService.swift
│   │   ├── GoogleAuthService.swift
│   │   └── TokenProvider.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   └── NetworkError.swift
│   ├── Security/
│   │   ├── JWT.swift
│   │   └── KeychainService.swift
│   ├── Session/
│   │   ├── AuthenticatedUser.swift
│   │   ├── SessionPersistence.swift
│   │   ├── SessionState.swift
│   │   └── SessionStore.swift
│   └── User/
│       └── UserService.swift
│
├── Features/
│   ├── Authentication/
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   └── Views/
│   │       └── AuthView.swift       # + private subviews in the same file or same folder
│   ├── Feed/
│   │   └── Views/
│   │       └── FeedView.swift
│   ├── Map/
│   │   └── Views/
│   │       └── MapView.swift
│   ├── Posts/                       # Future feature
│   ├── Profile/
│   │   └── Views/
│   │       └── ProfileView.swift
│   └── Search/
│       └── Views/
│           └── SearchView.swift
│
├── Shared/
│   └── DesignSystem/
│       ├── BrandColor.swift
│       └── BrandSpacing.swift
│
├── Assets.xcassets/
├── Info.plist
├── JordaniaTeam.entitlements
└── GoogleSignIn-Info.plist          # gitignored; .example file committed
```

---

## Placement Rules

### `App/`
Contains application-level types only: the entry point, the composition root, top-level navigation, and environment configuration. No business logic lives here.

- A new file belongs in `App/` only if it is application-level and has no feature-specific context.
- `MainTabView` belongs in `App/` because it orchestrates the top-level tab structure across all features — it is not owned by any single feature.

### `Core/`
Contains cross-cutting infrastructure used by multiple features. A type belongs in `Core/` if it is needed by more than one feature, or if it is foundational infrastructure (networking, security, session).

- `Core/Session/` — types that represent the authenticated session. Every feature that needs to know "who is logged in" reads from `SessionStore`.
- A model that is specific to one feature does **not** belong in `Core/`. It belongs inside `Features/<FeatureName>/`.

### `Features/`
One subfolder per feature. Each feature is self-contained.

- ViewModels go in `Features/<Feature>/ViewModels/`.
- Views go in `Features/<Feature>/Views/`.
- Models that belong exclusively to a feature go inside that feature folder (no prescribed subfolder; use judgement for small vs. large features).
- A feature must never import another feature. Shared logic belongs in `Core/`.

### `Shared/`
UI-only reusable components and design tokens. Contains no business logic, no services, and no ViewModels.

- A component belongs in `Shared/` only when it is used by two or more features and has no dependency on `Core/`.
- See [COMPONENTS.md](../design/COMPONENTS.md) for promotion criteria.

---

## Naming Conventions

| Type | Suffix | Example |
|---|---|---|
| SwiftUI View | `View` | `AuthView`, `FeedView` |
| ViewModel | `ViewModel` | `AuthViewModel` |
| Service (network/auth) | `Service` | `BackendAuthService`, `UserService` |
| Store (observable state) | `Store` | `SessionStore` |
| Persistence (Keychain/disk facade) | `Persistence` | `SessionPersistence` |
| Error enum | `Error` | `NetworkError`, `AuthError` |
| DTO | No suffix; `private` inside service file | `UserMeResponse` (private in `UserService.swift`) |
| Configuration | `Configuration` | `AppConfiguration` |
| Container (composition root) | `Container` | `AppContainer` |

**Files:** One primary type per file. The filename matches the primary type name exactly (`SessionStore.swift` contains `SessionStore`).

**Private subviews:** Small private SwiftUI subviews that are only used by one parent view may live in the same file as the parent, declared as `private struct`. Extract to a separate file only when the subview grows large enough to justify it.

---

## What Lives Where — Quick Reference

| If you are adding… | Put it in… |
|---|---|
| A new feature screen | `Features/<FeatureName>/Views/` |
| A ViewModel for a feature | `Features/<FeatureName>/ViewModels/` |
| A model used only by one feature | `Features/<FeatureName>/` |
| A model used by multiple features | `Core/<Subdomain>/` |
| A new network service | `Core/Networking/` or `Core/<Subdomain>/` |
| A reusable SwiftUI component (2+ features) | `Shared/` |
| A design token | `Shared/DesignSystem/` |
| App-level configuration | `App/AppConfiguration.swift` |
| A new third-party SDK bootstrap | `AppContainer.bootstrap()` |
