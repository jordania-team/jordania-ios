# Testing

**Purpose:** Defines the testing strategy, conventions, and coverage expectations for the Jordania iOS project.

**Scope:** Test strategy, Swift Testing patterns, and coverage targets. DI patterns that enable testing belong in [DEPENDENCY_INJECTION.md](DEPENDENCY_INJECTION.md).

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Framework](#framework)
3. [Unit Tests](#unit-tests)
4. [Integration Tests](#integration-tests)
5. [UI Tests](#ui-tests)
6. [Test Naming & Organisation](#test-naming--organisation)
7. [Coverage Targets](#coverage-targets)

---

## Testing Philosophy

<!-- Placeholder: test behaviour not implementation, tests must be fast and deterministic, no network calls in unit tests -->

## Framework

<!-- Placeholder: Swift Testing as the primary framework, @Test and @Suite macros, why XCTest is not used for new code -->

## Unit Tests

<!-- Placeholder: what to unit test (ViewModels, domain logic, parsers), how to inject fakes via initialiser DI, async test patterns with Swift Testing -->

## Integration Tests

<!-- Placeholder: what to integration test (AppContainer wiring, navigation flows), scope and when these are written -->

## UI Tests

<!-- Placeholder: scope of UI tests, XCUITest usage policy, what is and is not worth automating at the UI layer -->

## Test Naming & Organisation

<!-- Placeholder: file placement conventions (mirroring source structure), @Suite naming, @Test function naming pattern -->

## Coverage Targets

<!-- Placeholder: minimum coverage expectations per layer (ViewModel: high, View: low, Core: high), and how coverage is measured in CI -->
