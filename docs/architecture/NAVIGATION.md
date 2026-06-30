# Navigation

**Purpose:** Describes how the Jordania application navigates between screens — the state-driven root switch, the tab structure, and the conventions for intra-feature navigation.

**Scope:** Application-level and feature-level navigation patterns. Session state machine lives in [ARCHITECTURE.md](ARCHITECTURE.md). The `SessionStore` source of truth is described in [../backend/AUTHENTICATION.md](../backend/AUTHENTICATION.md).

---

## Table of Contents

1. [Navigation Philosophy](#navigation-philosophy)
2. [Root Navigation](#root-navigation)
3. [Tab Structure](#tab-structure)
4. [Feature Navigation](#feature-navigation)
5. [Navigation Rules](#navigation-rules)

---

## Navigation Philosophy

Navigation in Jordania is **state-driven, not imperative**. The visible screen is a pure function of `SessionStore.state`. No coordinator objects, no router singletons, no `NavigationPath` managed globally. SwiftUI's native navigation stack is the only tool used.

---

## Root Navigation

`RootView` owns the application-level navigation switch. It reads `container.sessionStore.state` and renders the appropriate top-level view:

```swift
// RootView.swift
switch container.sessionStore.state {
case .loading:              ProgressView()
case .authenticated:        MainTabView(container: container)
case .signedOut:            AuthView(session: container.sessionStore)
                                .environment(container.sessionStore)
case .error(let message):  SessionErrorView(message: message) { … }
}
```

### Session States

| State | Trigger | Screen shown |
|---|---|---|
| `.loading` | App launch, before Keychain read completes | `ProgressView` |
| `.authenticated` | Successful sign-in or valid persisted session | `MainTabView` |
| `.signedOut` | Explicit logout or expired/missing session | `AuthView` |
| `.error(message)` | Session validation failed with an unrecoverable error | `SessionErrorView` |

The transition from `.loading` to `.authenticated` or `.signedOut` happens synchronously in `SessionStore.init()` — the app never displays `.loading` for more than one frame under normal conditions.

The `.error` state is reached when `validateSession(using:)` fails for reasons other than `NetworkError.unauthorized`. A retry button calls `container.sessionStore.retry(using: container.userService)`, which resets to `.loading` and re-runs validation.

---

## Tab Structure

`MainTabView` uses the SwiftUI `TabView` with iOS 26's `Tab` API:

```swift
TabView {
    Tab("Feed",    systemImage: "rectangle.stack.fill") { FeedView()    }
    Tab("Map",     systemImage: "location.fill")         { MapView()     }
    Tab("Profile", systemImage: "person.fill")           { ProfileView() }
    Tab("Search",  systemImage: "magnifyingglass",
        role: .search)                                   { SearchView()  }
}
```

| Tab | Icon | Role | Entry view |
|---|---|---|---|
| Feed | `rectangle.stack.fill` | default | `FeedView` |
| Map | `location.fill` | default | `MapView` |
| Profile | `person.fill` | default | `ProfileView` |
| Search | `magnifyingglass` | `.search` | `SearchView` |

The `Search` tab uses `role: .search`, which enables the system search experience on iOS 26. `MainTabView` receives `AppContainer` and is responsible for propagating dependencies to feature views that need them.

---

## Feature Navigation

Intra-feature navigation uses `NavigationStack` with `navigationDestination(for:)`. Each feature owns its own stack.

Conventions:
- A feature's root view is always a plain `struct` with no `NavigationStack` wrapper — the tab provides the stack.
- Feature navigation state (the `NavigationPath`) is owned by the feature's root ViewModel or a dedicated navigation ViewModel, never by the View itself.
- Modal presentations (sheets, full-screen covers) are controlled by a `@State` boolean in the presenting View, driven by a ViewModel action.

---

## Navigation Rules

- **No imperative navigation.** Never call `UINavigationController.pushViewController`. Use `NavigationLink` or `.navigationDestination`.
- **No cross-feature push.** A feature that needs to present content from another feature must use a shared model, not import the feature directly.
- **`RootView` is the only state switch.** No other view should conditionally render Auth vs. authenticated content.
- **`AppContainer` is passed explicitly.** Features that need services receive them through their ViewModel's initialiser, not by reaching back up to `AppContainer`.
