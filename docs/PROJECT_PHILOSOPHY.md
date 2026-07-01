# Project Philosophy

**Purpose:** Defines the values, priorities, and deliberate trade-offs that govern every engineering decision on Jordania.

**Scope:** Why the project exists and what it optimises for — not how it is built (see [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md)) or what rules to follow (see [architecture/ENGINEERING_RULES.md](architecture/ENGINEERING_RULES.md)).

---

## Table of Contents

1. [Mission](#mission)
2. [What Jordania Is](#what-jordania-is)
3. [Goals](#goals)
4. [What Jordania Optimises For](#what-jordania-optimises-for)
5. [Deliberate Non-Goals](#deliberate-non-goals)
6. [Guiding Principles](#guiding-principles)
7. [Platform Commitment](#platform-commitment)

---

## Mission

Jordania exists to prove that a small team at the Apple Developer Academy can build a real, production-quality iOS application — not a tutorial project, not a prototype — while learning the engineering practices that define the best iOS teams in the industry.

The product is a social network for pets. The real deliverable is the engineering discipline required to build it correctly.

---

## What Jordania Is

Jordania is an iOS-first social network where pet owners share moments, discover nearby pets and events, and connect with other owners. The application is native SwiftUI, targets iOS 26+, and communicates with a backend API at `api.redepets.xyz`.

The project was initiated at the Apple Developer Academy as a team effort. It is not an academic exercise — the code runs on real devices, integrates real OAuth providers (Sign in with Apple, Google Sign-In), persists data in the Keychain, and communicates over a real network. Every decision is made as if the app will reach the App Store.

---

## Goals

### Product Goals

- Provide pet owners with a dedicated social space — separate from general-purpose networks — where the pet is the subject, not an afterthought.
- Allow owners to discover nearby pets and other owners through a map-based feature.
- Enable sharing of posts and moments associated with a pet's profile.
- Support search across users, pets, and content.

### Engineering Goals

- Build a codebase that serves as a reference for modern iOS engineering — one that a senior iOS engineer would read and find correct.
- Demonstrate that a small team can apply Lightweight MVVM, Feature-Based Architecture, strict dependency injection, and Swift 6 concurrency without overengineering.
- Produce a networking and authentication layer that handles token lifecycle, Keychain persistence, and multi-provider OAuth at a production level of correctness.
- Maintain a codebase that is easy to navigate, change, and extend — not one that is impressive to describe but painful to modify.

### Educational Goals

- Give every team member real experience with the engineering practices used at Apple and in leading iOS product teams.
- Make architectural decisions explicit and logged, so the reasoning behind the codebase is learnable, not just observable.
- Use Swift 6 features — `@Observable`, Async/Await, Strict Concurrency, Swift Testing — from the start, so the team learns the current language and platform, not its legacy.
- Produce documentation of sufficient quality that a new team member can onboard without requiring live explanation.

---

## What Jordania Optimises For

These priorities are ordered. When two principles conflict, the higher one wins.

1. **Correctness** — The app behaves correctly, handles errors, and never loses user data. A feature that works incorrectly is worse than a feature that does not exist.
2. **Clarity** — Code and architecture must be understandable by any team member without prior context. Clever solutions are rejected if a simpler one is available.
3. **Modern Apple technology** — Native SwiftUI, `@Observable`, Async/Await, Swift Testing. No wrappers, no bridging layers, no compatibility shims.
4. **Security** — Authentication tokens live in the Keychain only. The JWT is never exposed to the UI layer. Sign in with Apple is the primary auth provider.
5. **Maintainability** — The architecture must support adding features without touching unrelated code. Every feature is self-contained.
6. **Learning** — Decisions that create better learning opportunities are preferred over decisions that are marginally more efficient but less instructive.

---

## Deliberate Non-Goals

These are not oversights. They are explicit decisions, each with a reason.

| Non-Goal | Reason |
|---|---|
| Enterprise-scale architecture | Repository layers, Use Cases, and Coordinators add indirection that is not justified at this team and codebase size. Lightweight MVVM is sufficient. |
| Massive scalability | The backend and data model are not designed for millions of users. Premature scalability engineering would produce complexity with no corresponding benefit. |
| Multi-platform support | Jordania is an iOS application. SwiftUI on iPad is supported as a consequence of good iOS design. macOS, watchOS, and visionOS targets are out of scope. |
| Premature abstraction | No abstraction is introduced before it is needed by two real consumers in the codebase. Protocol wrappers around concrete types that have one implementation are rejected. |
| Dependency injection frameworks | Swinject, Needle, and similar tools add a compile-time or runtime layer that is not warranted when `AppContainer` with initialiser injection is sufficient. |
| Third-party UI frameworks | No component libraries, design systems, or UI kits from third parties. All UI is native SwiftUI, styled to the Jordania design system. |
| Feature flags and A/B testing infrastructure | Unnecessary at this stage. Features ship complete or not at all. |

---

## Guiding Principles

**Delete before abstracting.** When a pattern appears twice, consider whether duplication is actually a problem before introducing an abstraction. A third real instance justifies extraction.

**The file is the unit of ownership.** Every Swift file has a single, named responsibility. If describing a file's purpose requires the word "and", it should be split.

**Compile-time safety over runtime safety.** Swift's type system is the first line of defence. Errors that can be caught at compile time must never be deferred to runtime.

**The architecture must be visible in the folder structure.** A new team member should be able to infer the architectural shape of the project from the directory tree alone, without reading any code.

**Security is not a feature.** Authentication, token management, and Keychain storage are not optional or deferrable. They are correct from the first commit or they are not acceptable.

**Explicit over implicit.** Dependencies are passed through initialisers. State is owned by a named type. Side effects are in async functions, not property setters. Nothing happens by magic.

---

## Platform Commitment

Jordania targets Swift 6 and iOS 26+ from the first line of code. This is not a preference — it is a constraint enforced by the project.

| Technology | Commitment |
|---|---|
| `@Observable` | All observable state uses the Observation framework. `ObservableObject` is not used in new code. |
| Async/Await | All asynchronous operations use structured concurrency. Completion handlers and Combine are not used in new code. |
| Strict Concurrency | The project compiles with strict concurrency checking enabled. Data races are compile-time errors, not runtime surprises. |
| Swift Testing | All new tests use the Swift Testing framework (`@Test`, `@Suite`). XCTest is not used for new test code. |
| SwiftUI | All UI is written in SwiftUI. UIKit is used only when a SwiftUI equivalent does not exist. |

The consequence of this commitment is that no `#available` check is ever written to support an older OS version. If a feature requires iOS 26+, it requires iOS 26+. There is no compatibility fallback.
