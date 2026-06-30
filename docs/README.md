# Jordania iOS — Engineering Documentation

Jordania is an iOS-first social network for pets, built at the Apple Developer Academy using modern Apple technologies as a deliberate learning platform for production-grade iOS engineering.

This directory is the official engineering reference for the project. Every architectural decision, convention, and domain concept has exactly one authoritative document. When something is not documented here, the Swift source code in `JordaniaTeam/` is the source of truth.

---

## Platform Baseline

| Dimension | Value |
|---|---|
| Language | Swift 6 |
| Minimum deployment target | iOS 26 |
| Xcode | Latest stable |
| iOS SDK | Latest stable |
| State management | `@Observable` (Observation framework) |
| Concurrency | Async/Await + Strict Concurrency |
| Testing | Swift Testing |

Backward compatibility code is never introduced. `#available` guards are forbidden unless explicitly approved. There is no polyfill layer.

---

## Documentation Map

### This layer — Project context

| Document | Answers |
|---|---|
| [PROJECT_PHILOSOPHY.md](PROJECT_PHILOSOPHY.md) | Why Jordania exists and what it optimises for |
| [ROADMAP.md](ROADMAP.md) | What has been built and what comes next |
| [DOMAIN.md](DOMAIN.md) | The entities, vocabulary, and invariants of the domain |

### Architecture layer

| Document | Answers |
|---|---|
| [architecture/ENGINEERING_RULES.md](architecture/ENGINEERING_RULES.md) | Non-negotiable constraints every contributor must follow |
| [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Layers, dependency flow, and the composition root |
| [architecture/PROJECT_STRUCTURE.md](architecture/PROJECT_STRUCTURE.md) | Where every kind of file lives and why |
| [architecture/NAVIGATION.md](architecture/NAVIGATION.md) | How screens are presented and coordinated |
| [architecture/DECISION_LOG.md](architecture/DECISION_LOG.md) | Append-only log of significant architectural decisions |

### iOS layer

| Document | Answers |
|---|---|
| [ios/SWIFT_STYLE_GUIDE.md](ios/SWIFT_STYLE_GUIDE.md) | Formatting, naming, and language-usage rules |
| [ios/MVVM_GUIDELINES.md](ios/MVVM_GUIDELINES.md) | What Lightweight MVVM means in practice |
| [ios/DEPENDENCY_INJECTION.md](ios/DEPENDENCY_INJECTION.md) | How dependencies are wired, from `AppContainer` to Views |
| [ios/UI_GUIDELINES.md](ios/UI_GUIDELINES.md) | SwiftUI patterns, HIG compliance, accessibility |
| [ios/TESTING.md](ios/TESTING.md) | Swift Testing strategy and coverage expectations |

### Backend layer

| Document | Answers |
|---|---|
| [backend/AUTHENTICATION.md](backend/AUTHENTICATION.md) | Auth flows, JWT lifecycle, Keychain storage |
| [backend/API_GUIDELINES.md](backend/API_GUIDELINES.md) | How the iOS client communicates with the backend |
| [backend/ERROR_HANDLING.md](backend/ERROR_HANDLING.md) | Error taxonomy, propagation, and user-facing presentation |

### Design layer

| Document | Answers |
|---|---|
| [design/DESIGN_SYSTEM.md](design/DESIGN_SYSTEM.md) | Colour, typography, spacing, motion tokens |
| [design/COMPONENTS.md](design/COMPONENTS.md) | Reusable SwiftUI components in `Shared/` |

---

## Repository Layout

```
jordania-ios/
├── JordaniaTeam/          # Xcode project — all Swift source code
│   ├── App/               # Entry point, AppContainer, RootView, MainTabView
│   ├── Core/              # Authentication, Networking, Security, Session, User
│   ├── Features/          # Authentication, Feed, Map, Posts, Profile, Search
│   └── Shared/            # Reusable SwiftUI views
├── JordaniaTeam.xcodeproj/
└── docs/                  # This directory
```

---

## Quick Links

- **New to the project?** Start with [PROJECT_PHILOSOPHY.md](PROJECT_PHILOSOPHY.md), then [DOMAIN.md](DOMAIN.md).
- **Starting a feature?** Read [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) and [ios/MVVM_GUIDELINES.md](ios/MVVM_GUIDELINES.md).
- **Unsure where a file belongs?** See [architecture/PROJECT_STRUCTURE.md](architecture/PROJECT_STRUCTURE.md).
- **Making an architectural decision?** Log it in [architecture/DECISION_LOG.md](architecture/DECISION_LOG.md).
