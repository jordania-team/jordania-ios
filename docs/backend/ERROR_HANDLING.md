# Error Handling

**Purpose:** Defines how errors are represented, propagated, and surfaced to the user across the application.

**Scope:** Error taxonomy, propagation strategy, and user-facing presentation. API response shape belongs in [API_GUIDELINES.md](API_GUIDELINES.md). Authentication-specific failures belong in [AUTHENTICATION.md](AUTHENTICATION.md).

---

## Table of Contents

1. [Error Taxonomy](#error-taxonomy)
2. [Error Propagation](#error-propagation)
3. [User-Facing Presentation](#user-facing-presentation)
4. [Logging & Observability](#logging--observability)
5. [Rules](#rules)

---

## Error Taxonomy

<!-- Placeholder: domain error types — NetworkError, AuthError, DecodingError, ValidationError — their structure (enums with associated values), and when each is used -->

## Error Propagation

<!-- Placeholder: how errors travel from the networking layer through ViewModels to Views — throws vs Result, when to recover vs surface -->

## User-Facing Presentation

<!-- Placeholder: how errors are shown in the UI — inline validation errors, alert dialogs, banner notifications — and which error types map to which presentation -->

## Logging & Observability

<!-- Placeholder: what is logged, what is not, OSLog usage, redacting sensitive data from logs -->

## Rules

<!-- Placeholder: no force-try in production code, no empty catch blocks, all thrown errors must be either handled or re-thrown with context, localised user-facing messages required -->
