# Project Structure

**Purpose:** Describes the physical folder layout of the Jordania iOS project and explains the rules that determine where each type of file belongs.

**Scope:** Folder organisation, file placement rules, and naming conventions at the file-system level. Architecture layers are described in [ARCHITECTURE.md](ARCHITECTURE.md). Feature-level MVVM layout is described in [../ios/MVVM_GUIDELINES.md](../ios/MVVM_GUIDELINES.md).

---

## Table of Contents

1. [Top-Level Layout](#top-level-layout)
2. [App/](#app)
3. [Core/](#core)
4. [Features/](#features)
5. [Shared/](#shared)
6. [Placement Rules](#placement-rules)

---

## Top-Level Layout

```
JordaniaTeam/
├── App/
│   ├── AppConfiguration.swift
│   ├── AppContainer.swift
│   ├── JordaniaTeamApp.swift
│   ├── MainTabView.swift
│   └── RootView.swift
├── Assets.xcassets
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
├── Features/
│   ├── Authentication/
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   └── Views/
│   │       └── AuthView.swift
│   ├── Feed/
│   ├── Map/
│   ├── Posts/
│   ├── Profile/
│   └── Search/
├── Shared/
│   └── DesignSystem/
│       ├── BrandColors.swift
│       └── BrandSpacing.swift
├── Info.plist
└── JordaniaTeam.entitlements
```

---

## App/

Contains only application-lifecycle and composition-root files:

| File | Responsibility |
|---|---|
| `JordaniaTeamApp.swift` | `@main` entry point; creates `AppContainer` and calls `bootstrap()` |
| `AppContainer.swift` | Composition root; builds and owns the entire dependency graph |
| `AppConfiguration.swift` | Environment-specific constants (base URL, etc.) |
| `RootView.swift` | Switches between Auth, Onboarding, and MainTab based on `SessionState` |
| `MainTabView.swift` | Top-level `TabView` with Feed, Map, Profile, Search tabs |

Nothing else belongs in `App/`. In particular, feature Views and ViewModels must never be placed here.

---

## Core/

Cross-cutting infrastructure shared across features. Organised by concern, not by layer:

| Subfolder | Contents |
|---|---|
| `Authentication/` | Provider services (Apple, Google), backend auth service, token provider, auth errors |
| `Networking/` | `APIClient` (the single HTTP executor), `NetworkError` |
| `Security/` | Keychain wrapper, JWT parsing and expiry utilities |
| `Session/` | Observable session state, persistence, domain models (`AuthenticatedUser`, `SessionState`) |
| `User/` | `UserService` — fetches the authenticated user's profile |

`Core/` types may depend on each other (e.g., `TokenProvider` depends on `SessionPersistence` and `BackendAuthService`) but must never depend on `Features/`.

---

## Features/

Each feature is a self-contained vertical slice:

```
Features/
└── FeatureName/
    ├── ViewModels/
    │   └── FeatureViewModel.swift
    ├── Views/
    │   └── FeatureView.swift
    └── Models/           ← only if the feature has its own models
        └── FeatureModel.swift
```

Rules:
- A feature's `Models/` folder contains only models that belong exclusively to that feature.
- Features never import each other.
- Features import `Core/` for infrastructure and `Shared/` for UI components.
- The `ViewModels/` subfolder is required even if there is only one ViewModel.

Currently implemented features: `Authentication`, `Feed`, `Map`, `Posts`, `Profile`, `Search`.

---

## Shared/

Contains only reusable SwiftUI components and design-system tokens. Currently:

```
Shared/
└── DesignSystem/
    ├── BrandColors.swift    — asset-catalog colour accessors
    └── BrandSpacing.swift   — spacing and layout constants
```

Promotion criteria for a component to enter `Shared/`: it must be used in two or more features, contain no business logic, have no feature-specific dependencies, and carry its own Preview. See [../design/COMPONENTS.md](../design/COMPONENTS.md).

---

## Placement Rules

| Type | Belongs in |
|---|---|
| App entry point, composition root, root navigation | `App/` |
| Cross-cutting service used by ≥2 features | `Core/<concern>/` |
| Session, authentication models | `Core/Session/` |
| Feature ViewModel | `Features/<Name>/ViewModels/` |
| Feature View | `Features/<Name>/Views/` |
| Feature-specific model | `Features/<Name>/Models/` |
| Reusable SwiftUI component | `Shared/` (see promotion criteria) |
| Design-system token | `Shared/DesignSystem/` |
| Asset catalog | `Assets.xcassets` |
