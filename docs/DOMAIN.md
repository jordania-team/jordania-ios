# Domain

**Purpose:** Defines the business domain of Jordania — the core entities, their relationships, and the shared vocabulary used consistently across the codebase, documentation, and team communication.

**Scope:** Domain concepts and language only. Data models belong to their respective features in `Features/` or to `Core/Session` for session models. Persistence and API contracts belong in `backend/`. This document defines *what* things are, not *how* they are implemented.

---

## Table of Contents

1. [Ubiquitous Language](#ubiquitous-language)
2. [Core Entities](#core-entities)
3. [Entity Relationships](#entity-relationships)
4. [Session and Identity](#session-and-identity)
5. [Domain Invariants](#domain-invariants)
6. [Terminology to Avoid](#terminology-to-avoid)

---

## Ubiquitous Language

These terms have precise meanings in Jordania. Use them consistently in code, documentation, and conversation. When the meaning of a term is ambiguous, refer to this document.

| Term | Definition |
|---|---|
| **User** | A human being who has an account on Jordania. Identified by a UUID assigned by the backend. Created via Sign in with Apple or Google Sign-In. |
| **AuthenticatedUser** | The in-memory and Keychain-persisted representation of a signed-in User. Contains the User's ID, display name, email, and the `AuthProvider` used to sign in. |
| **AuthProvider** | The OAuth identity provider used to authenticate. Currently `apple` or `google`. The string representation is the contract with the backend (`"apple"`, `"google"`). |
| **Session** | The active authenticated context for a User. A Session exists when a valid JWT is present in the Keychain and the `SessionStore` state is `.authenticated`. |
| **SessionState** | The four possible states of the Session machine: `.loading`, `.authenticated`, `.signedOut`, `.error(String)`. Owned and broadcast by `SessionStore`. |
| **Pet** | An animal owned by a User. A Pet has its own profile, posts, and can be followed by other Users. The Pet is the primary social actor in the domain — not the User. |
| **Owner** | A User who has created at least one Pet. An Owner is a User; the term is used when the ownership relationship to a Pet is relevant. |
| **Post** | A piece of content published by a Pet's Owner, attributed to a specific Pet. A Post contains at minimum one image and an optional caption. |
| **Feed** | The chronological list of Posts from Pets that a User follows. The Feed is the primary content surface of the application. |
| **Follow** | A directional relationship from a User to a Pet. A User follows a Pet; a Pet does not follow back. |
| **Search** | The act of finding Users, Pets, or content by name or attribute. Search is a feature, not just a UI element. |
| **Map** | The location-based feature that shows nearby Pets whose Owners have opted into location sharing. |
| **JWT** | The JSON Web Token issued by the Jordania backend after a successful authentication exchange. The JWT is the credential used in every authenticated API request. It never appears in the UI layer. |
| **Access Token** | The short-lived JWT used to authenticate API requests. Stored in the Keychain exclusively. |
| **Refresh Token** | The long-lived token used to obtain a new Access Token when the current one expires. Stored in the Keychain exclusively. |
| **Token Exchange** | The process by which the iOS client sends an Apple or Google identity token to the backend (`/auth/apple` or `/auth/google`) and receives a Jordania JWT in return. |
| **Keychain** | The iOS system Keychain. The only acceptable storage location for tokens and the serialised `AuthenticatedUser`. |
| **AppContainer** | The single object that creates and owns all application dependencies. Created once at launch by `JordaniaTeamApp`. |
| **SessionStore** | The `@Observable` object that is the single source of truth for session state. Observed by `RootView` to make routing decisions. |
| **Feature** | A self-contained vertical slice of the application: Authentication, Feed, Map, Posts, Profile, or Search. Each Feature has its own folder in `Features/` and owns its models, ViewModels, and Views. |

---

## Core Entities

### User

A User is the account holder. Users are created implicitly during the first authentication — there is no separate registration step. The backend creates the User record on the first successful token exchange.

Properties known to the iOS client (via `AuthenticatedUser`):
- `id` — UUID assigned by the backend.
- `name` — Display name. Optional because Sign in with Apple allows users to withhold their name after the first sign-in.
- `email` — Email address. Optional for the same reason.
- `provider` — The `AuthProvider` used to create the account.

### Pet

A Pet is the primary social actor. While Users hold accounts, Pets hold profiles and publish Posts. A User can own multiple Pets.

The Pet entity is defined in `Features/Profile`. Its full model is documented there.

### Post

A Post is a piece of content attributed to a specific Pet. Posts appear in the Feeds of Users who follow that Pet. A Post belongs to exactly one Pet.

The Post entity is defined in `Features/Posts`. Its full model is documented there.

### Feed

A Feed is not a stored entity — it is a computed view of Posts from Pets a User follows, ordered by creation time descending. The Feed has no identity of its own.

---

## Entity Relationships

```
User ──────────── owns ──────────── Pet (one-to-many)
User ──────────── follows ─────────── Pet (many-to-many)
Pet  ──────────── publishes ────────── Post (one-to-many)
Feed ─────────── aggregates ────────── Post (derived, not stored)
User ─── has one ─── Session
Session ─── contains ─── AuthenticatedUser
```

Key ownership rules:
- A Pet must always belong to exactly one User (Owner). A Pet without an Owner is an invalid state.
- A Post must always be attributed to exactly one Pet. A Post without a Pet is an invalid state.
- A Session belongs to exactly one User. There is never more than one active Session on a device.

---

## Session and Identity

The session layer is the most security-critical part of the domain. It lives in `Core/Session` and `Core/Security` — not in any Feature.

**Authentication flow (high level):**

1. The user taps "Sign in with Apple" or "Sign in with Google".
2. The iOS provider SDK returns an identity token.
3. `BackendAuthService` exchanges the identity token with the Jordania backend.
4. The backend responds with an `AuthenticatedUser`, an Access Token, and a Refresh Token.
5. `SessionStore.signIn` persists all three to the Keychain via `SessionPersistence`.
6. `SessionStore.state` transitions to `.authenticated`.
7. `RootView` observes the state change and presents `MainTabView`.

**Session restoration on launch:**

1. `SessionStore.init` reads the `AuthenticatedUser` from the Keychain.
2. If present, state is immediately set to `.authenticated` (no network call, no spinner).
3. `JordaniaTeamApp` calls `sessionStore.validateSession` in background — if the token is expired or revoked, the user is signed out gracefully.

**The JWT is never in the UI layer.** `SessionStore` exposes `currentUser: AuthenticatedUser?` and `state: SessionState`. Token values are read exclusively by `APIClient` via `TokenProvider` at the moment of each request.

---

## Domain Invariants

These rules are always true, regardless of implementation. Violating them is a bug.

- A Pet must have exactly one Owner.
- A Post must be attributed to exactly one Pet.
- There is at most one active Session per device.
- The JWT (Access Token and Refresh Token) is stored only in the Keychain. It is never written to UserDefaults, in-memory caches exposed to the UI, or any form of logging.
- `SessionStore.state` is the single source of truth for authentication state. No other part of the application duplicates this state.
- `AuthProvider.rawValue` (`"apple"`, `"google"`) is the contract with the backend. These values must never be changed without a coordinated backend migration.

---

## Terminology to Avoid

These terms are imprecise or inconsistent with the domain model. Do not use them in code, comments, or documentation.

| Avoid | Use instead | Reason |
|---|---|
| `currentUser` as a global | `SessionStore.currentUser` | There is no global `currentUser`. It is a property on `SessionStore`. |
| "logged in" / "logged out" | "signed in" / "signed out" | Consistent with Apple's own terminology for Sign in with Apple. |
| "token" (unqualified) | "Access Token" or "Refresh Token" | The project has two distinct tokens. Unqualified "token" is ambiguous. |
| "profile" to mean User | "User profile" or "Pet profile" | Both Users and Pets have profiles. Always qualify the noun. |
| "account" | "User" | In the Jordania domain, the entity is a User. "Account" has no precise definition here. |
