# UI Guidelines

**Purpose:** Define how SwiftUI views are written in Jordania — layout, state observation, accessibility, and native platform behaviour.

**Scope:** Everything that lives inside a `View` body, a `#Preview`, or `Shared/`. Does not cover ViewModel responsibilities (see `MVVM_GUIDELINES.md`), navigation wiring (see `NAVIGATION.md`), or design tokens (see `DESIGN_SYSTEM.md`).

---

## Table of Contents

1. [Platform Baseline](#platform-baseline)
2. [View Responsibility](#view-responsibility)
3. [State & Observation](#state--observation)
4. [Layout Patterns](#layout-patterns)
5. [Dark Mode & Color Scheme](#dark-mode--color-scheme)
6. [Accessibility](#accessibility)
7. [Previews](#previews)
8. [Naming & File Organisation](#naming--file-organisation)

---

## Platform Baseline

All UI targets **iOS 26+ with SwiftUI**. Never introduce UIKit in a View or ViewModel. The single documented exception is `GoogleAuthService`, which must use a `UIViewController` to present the Google Sign In sheet — this is an SDK constraint, not a pattern to follow.

```swift
// Correct: pure SwiftUI
struct FeedView: View { ... }

// Wrong: UIKit wrapper in a feature View
struct FeedViewController: UIViewControllerRepresentable { ... }
```

Use the latest SwiftUI APIs without availability guards. Never write `if #available(iOS 17, *)` — the deployment target already enforces iOS 26.

---

## View Responsibility

A View in Jordania has exactly three responsibilities:

1. **Render** observable state as layout.
2. **Forward** user gestures to the ViewModel as method calls.
3. **Compose** child views.

A View must never:
- Contain business logic.
- Call a service directly.
- Own persistent state beyond transient UI state (e.g., `@FocusState`, scroll position).
- Know what a JWT is.

`AuthView` is the canonical example: the body reads `viewModel.isLoading` and `viewModel.errorMessage`, and calls `viewModel.handleAppleSignIn(_:)` or `viewModel.signInWithGoogle()`. It owns nothing else.

---

## State & Observation

Jordania uses the Observation framework exclusively (`@Observable`). `ObservableObject`, `@StateObject`, `@ObservedObject`, and `@EnvironmentObject` are **not used**.

### Owning a ViewModel

```swift
// Correct: @State owns the ViewModel
struct AuthView: View {
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }
}
```

`@State` is the right ownership mechanism for `@Observable` ViewModels created inside a View. The ViewModel is passed in via `init` — never created with a bare `AppContainer`.

### Reading cross-feature state

`SessionStore` is injected into the environment at the root:

```swift
// RootView injects it
AuthView(session: container.sessionStore)
    .environment(container.sessionStore)

// Feature views read it
@Environment(SessionStore.self) private var session
```

Only `SessionStore` travels through the environment. Feature-specific ViewModels are never put in the environment.

---

## Layout Patterns

### `safeAreaInset` for pinned bottom content

```swift
// Correct: auth buttons pinned to the safe area bottom
.safeAreaInset(edge: .bottom) {
    authButtonsSection
}
```

This is the documented pattern in `AuthView`. It respects the device safe area without hard-coded padding and works correctly on all iPhone form factors.

### Design system tokens for spacing

Never hardcode numeric spacing values inside a View. Use `BrandSpacing` tokens:

```swift
// Correct
.padding(.horizontal, BrandSpacing.screenHorizontal)
.padding(.bottom, BrandSpacing.screenBottom)
.frame(height: BrandSpacing.buttonHeight)

// Wrong
.padding(.horizontal, 24)
.frame(height: 50)
```

### Subview decomposition for `@Environment` correctness

When a child needs its own `@Environment(\.colorScheme)` read — as is the case with `SignInWithAppleButton` — extract it into a dedicated `private struct`. This forces SwiftUI to re-evaluate the environment read at the correct view boundary.

```swift
private struct AppleSignInButton: View {
    @Environment(\.colorScheme) private var colorScheme
    ...
}
```

The same pattern applies to any view whose appearance depends on an environment value that must react to runtime changes.

### `.id(colorScheme)` for forced recreation

`SignInWithAppleButton` (wrapping `ASAuthorizationAppleIDButton`) reads `colorScheme` only at creation time. Forcing recreation via `.id(colorScheme)` is the documented workaround for this SDK behaviour. Apply this technique only to stateless views where recreation has no cost.

---

## Dark Mode & Color Scheme

All views must support both light and dark mode. Rules:

- Use `BrandColors.primary` (Asset Catalog) and semantic SwiftUI colours (`.secondary`, `.background`, `.primary`) for automatic dark mode adaptation.
- Never hardcode `Color(.black)` or `Color(.white)` where a semantic colour would adapt automatically.
- When a non-adaptive colour is required (e.g., the Google Sign In button must be black in light, white in dark to match HIG), read `@Environment(\.colorScheme)` in an isolated subview and map explicitly.
- The Apple Sign In button style follows HIG: `.black` in light mode, `.white` in dark mode.

---

## Accessibility

- Every interactive element that has no visible text label must declare `.accessibilityLabel(_:)`.
- The Google Sign In button sets `.accessibilityLabel("Continue with Google")` explicitly because the asset name `"google-logo"` carries no semantic meaning for VoiceOver.
- `Image(systemName:)` is inherently accessible when used decoratively; add `.accessibilityHidden(true)` for purely decorative SF Symbols.
- Use `.multilineTextAlignment(.center)` on subtitle text when it may wrap, so VoiceOver reads it in the correct logical order.
- Buttons must have a minimum tap target of 44×44 pt. The `BrandSpacing.buttonHeight` of 50 pt satisfies this requirement for full-width buttons.

---

## Previews

Every View must have a `#Preview` macro. Previews must compile and render without a running backend.

```swift
#Preview {
    let session = SessionStore()    // .signedOut by default — no network
    AuthView(session: session)
        .environment(session)
}
```

Rules:
- Create dependencies directly in the preview — never reference `AppContainer` from a preview.
- Inject `SessionStore` into the environment when the view uses `@Environment(SessionStore.self)`.
- Keep previews stateless and deterministic.

---

## Naming & File Organisation

| Element | Convention | Example |
|---|---|---|
| Root View | `FeatureView.swift` | `AuthView.swift` |
| Private subview | Same file as parent | `private struct AppleSignInButton` inside `AuthView.swift` |
| Shared component | `Shared/` + descriptive name | `Shared/DesignSystem/BrandColors.swift` |
| Reusable UI component | `Shared/Components/` | `Shared/Components/PrimaryButton.swift` |
| Error / empty state | `FeatureErrorView.swift` or `FeatureEmptyView.swift` | `SessionErrorView.swift` |

Private subviews that are only used by one parent View live in the same file, declared `private struct`. Extract to a separate file only when a subview is reused in more than one place, in which case it belongs in `Shared/Components/`.
