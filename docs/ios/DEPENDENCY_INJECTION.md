# Dependency Injection

**Purpose:** Documents how dependencies are created, composed, and injected throughout the application.

**Scope:** DI strategy and patterns only. Where AppContainer lives structurally belongs in [PROJECT_STRUCTURE.md](../architecture/PROJECT_STRUCTURE.md). Architectural rationale belongs in [ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Table of Contents

1. [Strategy](#strategy)
2. [AppContainer](#appcontainer)
3. [Injecting into ViewModels](#injecting-into-viewmodels)
4. [Injecting into Views](#injecting-into-views)
5. [Testing with DI](#testing-with-di)
6. [What Is Forbidden](#what-is-forbidden)

---

## Strategy

<!-- Placeholder: initialiser injection only, explicit over implicit, compile-time-safe wiring — and why this was chosen over environment objects or a DI framework -->

## AppContainer

<!-- Placeholder: AppContainer as the single composition root — what it creates, the order of initialisation, and how it is passed into RootView -->

## Injecting into ViewModels

<!-- Placeholder: concrete pattern for injecting a service into a ViewModel via initialiser, including protocol vs concrete type trade-offs -->

## Injecting into Views

<!-- Placeholder: how ViewModels are passed into Views (initialiser), the rule against @EnvironmentObject for application dependencies -->

## Testing with DI

<!-- Placeholder: how initialiser injection enables substituting fakes/mocks in Swift Testing without a container -->

## What Is Forbidden

<!-- Placeholder: Service Locator pattern, singleton dependencies accessed via static properties, DI frameworks (Swinject, Needle, etc.) -->
