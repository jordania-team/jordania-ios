# Navigation

**Purpose:** Documents the navigation architecture of the application — how screens are presented, dismissed, and coordinated.

**Scope:** Navigation patterns and the role of RootView and MainTabView only. Individual screen content belongs to each feature's documentation.

---

## Table of Contents

1. [Navigation Architecture](#navigation-architecture)
2. [RootView — Application Flow Coordinator](#rootview--application-flow-coordinator)
3. [MainTabView](#maintabview)
4. [Feature Navigation](#feature-navigation)
5. [Deep Links](#deep-links)
6. [Rules](#rules)

---

## Navigation Architecture

<!-- Placeholder: description of the chosen navigation approach — NavigationStack, sheet presentation, tab-based root — and why SwiftUI-native navigation was preferred -->

## RootView — Application Flow Coordinator

<!-- Placeholder: RootView's single responsibility — deciding whether to show authentication or the main app based on session state — and how it observes Core/Session -->

## MainTabView

<!-- Placeholder: tab structure, which features map to which tabs, and why MainTabView lives in App/ and not inside a feature -->

## Feature Navigation

<!-- Placeholder: how features navigate internally (NavigationStack owned by the feature) and the rule that features do not push directly into other features -->

## Deep Links

<!-- Placeholder: how deep links are handled, which layer intercepts them, and where routing decisions are made -->

## Rules

<!-- Placeholder: navigation-specific rules — no feature may present another feature's root view directly, navigation state is not stored in Core, etc. -->
