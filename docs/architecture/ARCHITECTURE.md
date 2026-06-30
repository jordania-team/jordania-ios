# Architecture Overview

**Purpose:** Describes the overall architectural shape of the Jordania iOS application — the layers, their responsibilities, and how they interact.

**Scope:** High-level structure and data-flow. File/folder layout belongs in [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md). Navigation details belong in [NAVIGATION.md](NAVIGATION.md). Feature-level MVVM details belong in [ios/MVVM_GUIDELINES.md](../ios/MVVM_GUIDELINES.md).

---

## Table of Contents

1. [Architectural Style](#architectural-style)
2. [Layer Map](#layer-map)
3. [Dependency Flow](#dependency-flow)
4. [Composition Root](#composition-root)
5. [State Management](#state-management)
6. [Key Constraints](#key-constraints)

---

## Architectural Style

<!-- Placeholder: description of Feature-Based Architecture + Lightweight MVVM, why this was chosen over alternatives, and what "lightweight" means in this context -->

## Layer Map

<!-- Placeholder: diagram/table of App → Features → Core → Shared, each layer's single responsibility, and what may and may not cross each boundary -->

## Dependency Flow

<!-- Placeholder: description of the unidirectional dependency graph — outer layers depend on inner, nothing in Core or Shared may import a Feature -->

## Composition Root

<!-- Placeholder: role of AppContainer as the single place where dependencies are created and wired; how it relates to RootView -->

## State Management

<!-- Placeholder: how application state is managed — @Observable, where ViewModels live, how session state propagates from Core/Session outward -->

## Key Constraints

<!-- Placeholder: summary of the most important architectural constraints (no global Models folder, no Service Locator, no premature modularisation) and the principle behind each -->
