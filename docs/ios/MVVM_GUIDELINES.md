# MVVM Guidelines

**Purpose:** Defines what Lightweight MVVM means in Jordania — the responsibilities of each layer, the boundary rules, and the patterns that are and are not acceptable.

**Scope:** ViewModel and View design within a feature. Cross-feature coordination belongs in [ARCHITECTURE.md](../architecture/ARCHITECTURE.md). DI wiring belongs in [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md).

---

## Table of Contents

1. [What "Lightweight" Means](#what-lightweight-means)
2. [ViewModel Responsibilities](#viewmodel-responsibilities)
3. [View Responsibilities](#view-responsibilities)
4. [Model Responsibilities](#model-responsibilities)
5. [Boundaries & Rules](#boundaries--rules)
6. [Patterns to Avoid](#patterns-to-avoid)

---

## What "Lightweight" Means

<!-- Placeholder: explicit statement that there is no Repository layer, no UseCase objects, no Coordinator objects — and the reasoning why these abstractions are deferred -->

## ViewModel Responsibilities

<!-- Placeholder: owns async operations for its feature, transforms raw data into view state, calls services injected via initialiser, is @Observable -->

## View Responsibilities

<!-- Placeholder: renders state, forwards user intent to ViewModel, no business logic, no direct network calls -->

## Model Responsibilities

<!-- Placeholder: plain value types (structs) representing domain data, defined in the feature that owns them, no UI imports -->

## Boundaries & Rules

<!-- Placeholder: Views never reach past ViewModel into services, ViewModels never import SwiftUI, Models never import networking layer -->

## Patterns to Avoid

<!-- Placeholder: Massive ViewModel, business logic in View body, shared mutable ViewModels across features, ObservableObject (use @Observable instead) -->
