# Design System

**Purpose:** Document the visual design tokens used in Jordania — colours, spacing, and the conventions for extending the design system.

**Scope:** Token definitions and usage rules. Does not cover individual components (see `COMPONENTS.md`) or SwiftUI implementation patterns (see `UI_GUIDELINES.md`).

---

## Table of Contents

1. [Structure](#structure)
2. [Colours](#colours)
3. [Spacing](#spacing)
4. [Typography](#typography)
5. [Extending the Design System](#extending-the-design-system)

---

## Structure

Design system tokens live in `Shared/DesignSystem/` as Swift enums with `static let` properties. They are caseless enums — they cannot be instantiated.

```
Shared/
└── DesignSystem/
    ├── BrandColors.swift
    └── BrandSpacing.swift
```

No token is defined inline in a View. Every numeric or colour value used in layout must reference a token from this directory.

---

## Colours

Defined in `BrandColors.swift`.

```swift
enum BrandColors {
    static let primary = Color("BrandPrimary")
}
```

`BrandColors.primary` references an Asset Catalog named colour (`BrandPrimary`). Asset Catalog colours are used for brand colours because they support automatic Dark Mode variants — the light and dark appearance are defined in the `.xcassets`, not in code.

### Current tokens

| Token | Asset | Usage |
|---|---|---|
| `BrandColors.primary` | `BrandPrimary` | Primary brand accent — paw print icon, primary interactive elements |

### Semantic colours

Beyond `BrandColors`, views use SwiftUI's built-in semantic colours (`.primary`, `.secondary`, `.background`, `.red`) which adapt automatically to light/dark mode. Custom non-brand colours are not introduced without a design decision.

### Rules

- Never hardcode `Color(.black)` or `Color(.white)` except where explicit non-adaptive behaviour is required (e.g., sign-in button HIG compliance).
- When a non-adaptive explicit colour is needed, document the reason in a code comment at the call site.
- New brand colours must be added to both the Asset Catalog (with light/dark variants) and `BrandColors.swift`.

---

## Spacing

Defined in `BrandSpacing.swift`.

```swift
enum BrandSpacing {
    static let screenHorizontal: CGFloat  = 24   // Horizontal padding on screen edges
    static let buttonHeight: CGFloat      = 50   // Standard tappable button height
    static let screenBottom: CGFloat      = 24   // Bottom safe area inset padding
    static let buttonCornerRadius: CGFloat = 8   // Corner radius for action buttons
}
```

### Token semantics

| Token | Value | Meaning |
|---|---|---|
| `screenHorizontal` | 24 pt | Standard horizontal padding from screen edges |
| `buttonHeight` | 50 pt | Full-width button height (exceeds 44 pt accessibility minimum) |
| `screenBottom` | 24 pt | Padding above the home indicator / bottom safe area |
| `buttonCornerRadius` | 8 pt | Corner radius for primary and secondary buttons |

### Rules

- All padding and sizing values in Views must reference a `BrandSpacing` token.
- If a layout requires a value not covered by existing tokens, add the token to `BrandSpacing.swift` with a name and a comment describing its purpose — never use a bare numeric literal.

---

## Typography

Jordania uses SwiftUI's dynamic type system exclusively. No custom font is registered at this stage.

```swift
Text("iPet")
    .font(.largeTitle)
    .fontWeight(.bold)

Text("The social network for your pets")
    .font(.subheadline)
    .foregroundStyle(.secondary)
```

Text styles used in the current codebase:

| Style | Usage |
|---|---|
| `.largeTitle` | App name / hero heading |
| `.headline` | Section titles, error headings |
| `.subheadline` | Subtitles, secondary descriptions |
| `.footnote` | Inline error messages |
| `system(size:19, weight:.medium)` | Google Sign In button label (matches Apple button typography) |

All text styles support Dynamic Type automatically. Custom `system(size:)` values must document the reason they cannot use a standard style.

---

## Extending the Design System

When a new visual property is needed across multiple views:

1. Add a `static let` to the appropriate `Brand*.swift` file.
2. Name it semantically (what it represents, not what it looks like): `BrandSpacing.cardPadding`, not `BrandSpacing.sixteen`.
3. If the property is colour, add it to the Asset Catalog with light and dark variants before referencing it in code.
4. If the property is a new category (e.g., animation durations, shadow styles), create a new `Brand*.swift` file in `Shared/DesignSystem/`.

Do not create feature-local design constants. All shared visual values belong in `Shared/DesignSystem/`.
