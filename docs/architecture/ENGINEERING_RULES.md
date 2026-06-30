# Engineering Rules

**Purpose:** Non-negotiable rules that all contributors must follow. The authoritative list of constraints that keep the codebase consistent and maintainable.

**Scope:** Mandatory rules only — what is forbidden and what is required. Guidelines and preferences live in the iOS-specific docs (`ios/`). Rationale for each rule lives here; the broader context lives in [PROJECT_PHILOSOPHY.md](../PROJECT_PHILOSOPHY.md).

---

## Table of Contents

1. [Code Organisation](#code-organisation)
2. [Dependency Management](#dependency-management)
3. [Concurrency](#concurrency)
4. [Data Ownership](#data-ownership)
5. [Forbidden Patterns](#forbidden-patterns)
6. [Platform Baseline Enforcement](#platform-baseline-enforcement)

---

## Code Organisation

<!-- Placeholder: rules on file placement — models live in their feature, session models live in Core/Session, MainTabView lives in App/, Shared is UI-only — with rationale -->

## Dependency Management

<!-- Placeholder: rules on DI — initialiser-based only, no Service Locator, no DI framework, AppContainer is the single composition root -->

## Concurrency

<!-- Placeholder: rules for Swift 6 strict concurrency — no data races, correct actor usage, Sendable conformance requirements -->

## Data Ownership

<!-- Placeholder: rules on where models are defined, how state flows, and who owns mutations -->

## Forbidden Patterns

<!-- Placeholder: explicit list of patterns that must never appear — singletons (outside AppContainer), global state, force unwraps in production code, premature modularisation, etc. -->

## Platform Baseline Enforcement

<!-- Placeholder: rule that no backward-compatibility code is ever introduced, no `#available` guards unless explicitly approved, minimum deployment target is iOS 26 -->
