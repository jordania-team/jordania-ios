# Components

**Purpose:** Catalogue the reusable UI components that live in `Shared/` and define the rules for when a component should be promoted to `Shared/`.

**Scope:** Only components in `Shared/`. Feature-specific views remain in their feature folder and are not documented here. For design tokens, see `DESIGN_SYSTEM.md`. For View composition patterns, see `UI_GUIDELINES.md`.

---

## Table of Contents

1. [Promotion Rules](#promotion-rules)
2. [Current Components](#current-components)
3. [Component Contract](#component-contract)
4. [Adding a New Component](#adding-a-new-component)

---

## Promotion Rules

A View is promoted to `Shared/` when **all** of the following are true:

1. It is used in more than one feature.
2. It has no dependency on any feature-specific ViewModel or model.
3. Its only inputs are value types or closures — it accepts no `SessionStore`, `AppContainer`, or any Core type.
4. It is visually generic enough to be used in at least two distinct contexts without modification.

Views that are only used in one feature stay in that feature's `Views/` folder, even if they look like they might be reused one day. Premature promotion to `Shared/` creates coupling that is harder to undo than it looks.

---

## Current Components

### Design System

`Shared/DesignSystem/` — token files, not UI components. See `DESIGN_SYSTEM.md`.

### Authentication Buttons

`AppleSignInButton` and `GoogleSignInButton` are currently defined as `private struct` inside `AuthView.swift`. They are authentication-specific and not candidates for `Shared/` — they depend on `AuthenticationServices` and the Google Sign In SDK respectively, which are not general-purpose dependencies.

If a second entry point for authentication is introduced (e.g., a re-authentication sheet), these would be promoted to `Features/Authentication/Views/` as internal-but-non-private structs.

---

## Component Contract

Every component in `Shared/` must satisfy:

**Inputs via `init` only.** No `@Environment` reads except SwiftUI system values (`colorScheme`, `dynamicTypeSize`, `accessibilityReduceMotion`). Never inject `SessionStore` or any domain model.

**No side effects.** A component renders its inputs. It communicates upward through closures or bindings, never by mutating shared state directly.

**Dark mode compliant.** Uses `BrandColors` tokens or SwiftUI semantic colours. Never hardcodes light-only colours.

**Accessible.** Has a meaningful accessibility label. Interactive elements have a minimum 44×44 pt tap target.

**Preview included.** A `#Preview` that renders the component in isolation, covering its primary visual states.

---

## Adding a New Component

1. Create `Shared/Components/<ComponentName>.swift`.
2. Declare it `struct` with only value-type or closure properties.
3. Verify it satisfies the Component Contract above.
4. Add a `#Preview` covering the relevant states (default, loading, error, empty — as applicable).
5. Add an entry to the **Current Components** section of this file describing its purpose, inputs, and known usage.

When a component graduates from a feature's private struct to `Shared/Components/`, update the feature's View to import it from its new location and remove the private declaration.
