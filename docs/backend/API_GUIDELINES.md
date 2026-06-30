# API Guidelines

**Purpose:** Defines the conventions for how the iOS client communicates with the Jordania backend — request construction, response handling, and versioning.

**Scope:** API communication conventions only. Authentication headers and token management belong in [AUTHENTICATION.md](AUTHENTICATION.md). Error response structure belongs in [ERROR_HANDLING.md](ERROR_HANDLING.md).

---

## Table of Contents

1. [Base Configuration](#base-configuration)
2. [Request Conventions](#request-conventions)
3. [Response Conventions](#response-conventions)
4. [Versioning](#versioning)
5. [Networking Layer Design](#networking-layer-design)
6. [Testing API Calls](#testing-api-calls)

---

## Base Configuration

<!-- Placeholder: base URL management (environment-aware), timeout policy, URLSession configuration -->

## Request Conventions

<!-- Placeholder: how endpoints are defined in code, required headers (Content-Type, Authorization), JSON encoding strategy -->

## Response Conventions

<!-- Placeholder: expected envelope shape, JSON decoding strategy, how 2xx vs 4xx vs 5xx are handled at the networking layer -->

## Versioning

<!-- Placeholder: API versioning strategy (URL path vs header), how client version and API version are kept in sync -->

## Networking Layer Design

<!-- Placeholder: where the networking layer lives (Core/), how it is injected, async/await interface, no Combine in new code -->

## Testing API Calls

<!-- Placeholder: how to test networking code with fake URLSession or a protocol-based abstraction, no live network calls in unit tests -->
