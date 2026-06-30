# Project Structure

**Purpose:** Documents the exact folder structure of the Xcode project and the rule that governs where each kind of file lives.

**Scope:** Physical file organisation only. Architectural rationale belongs in [ARCHITECTURE.md](ARCHITECTURE.md). Navigation belongs in [NAVIGATION.md](NAVIGATION.md).

---

## Table of Contents

1. [Folder Tree](#folder-tree)
2. [App/](#app)
3. [Core/](#core)
4. [Features/](#features)
5. [Shared/](#shared)
6. [Placement Rules](#placement-rules)

---

## Folder Tree

<!-- Placeholder: annotated ASCII tree of the full project directory as it currently stands -->

## App/

<!-- Placeholder: what lives here — entry point, AppContainer, RootView, MainTabView — and why these are not inside a feature -->

## Core/

<!-- Placeholder: what lives here — Session, networking primitives, keychain utilities — and the rule that Core has no UI -->

## Features/

<!-- Placeholder: structure of a typical feature folder (View, ViewModel, Model, sub-features), and the rule that models never leave their feature -->

## Shared/

<!-- Placeholder: what lives here — reusable SwiftUI views only — and what is explicitly excluded (business logic, models, networking) -->

## Placement Rules

<!-- Placeholder: decision table — given a new file of type X, it belongs in folder Y — covering Views, ViewModels, Models, Services, Extensions, Constants -->
