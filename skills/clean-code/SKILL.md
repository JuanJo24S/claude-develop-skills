---
name: clean-code
description: Clean code standards, SOLID principles, hexagonal architecture, design patterns and testing. Use when writing, refactoring or reviewing code.
license: CC-BY-NC-SA-4.0 with an additional permission (see LICENSE.md)
metadata:
  author: Juan Camacho (JuanJo24S)
  source: https://github.com/JuanJo24S/claude-develop-skills
---

# Clean code and design patterns

Apply these principles pragmatically: the goal is code that is easy to read, test and change, not to pile up patterns. If a pattern doesn't solve a real, present problem, don't introduce it (YAGNI).

## Core principles

- **SOLID**
  - *S*: one class/module, one reason to change.
  - *O*: extend behavior without modifying stable code (strategies, polymorphism).
  - *L*: implementations must be substitutable for their abstraction without surprises.
  - *I*: small, client-specific interfaces.
  - *D*: the domain depends on abstractions (ports), not on frameworks or infrastructure.
- **DRY** with judgment: duplicating twice is fine; abstract on the third occurrence when the concept is truly the same.
- **KISS** and **YAGNI**: the simplest solution that meets the current requirement.
- **Fail fast**: validate inputs at the edges (controllers, event consumers) and raise explicit errors.

## Readability

- Names in **English**, descriptive and in the domain language (`calculateOrderTotal`, not `calc` or `doStuff`).
- Short functions that do one thing, with few parameters (≥4 → group them into an object/DTO).
- Avoid deep nesting: use guard clauses and early returns.
- No magic numbers or strings: named constants or enums.
- Comments only explain **why**, never what. No commented-out code in commits.
- Explicit error handling: meaningful domain exceptions; never catch and swallow.
- Immutability by default; minimize shared state and side effects.

## Architecture

For each application, service or module with business logic, use **hexagonal architecture (ports and adapters) / Clean Architecture**:

```
<app-or-service>/
├── domain/           # Entities, value objects, business rules, domain events. No external dependencies.
├── application/      # Use cases, inbound/outbound ports (interfaces), DTOs.
├── infrastructure/   # Adapters: DB repositories, HTTP clients, brokers, config.
└── interfaces/       # REST/gRPC controllers, event consumers, request ↔ DTO mapping.
```

- Dependencies point **inward**: `interfaces`/`infrastructure` → `application` → `domain`.
- Constructor dependency injection; never instantiate infrastructure inside the domain.
- Configuration via environment variables (12-Factor); never secrets in code.

## If the project uses microservices

- **Database per service**: each microservice owns its data; no one else accesses its DB directly.
- Boundaries defined by **Bounded Contexts** (DDD); avoid microservices that always change together.
- Explicit, versioned contracts (OpenAPI / AsyncAPI / Protobuf). Breaking changes → new version.
- Stateless services and **idempotent** operations where possible, especially event consumers.
- Observability: structured logs with a correlation ID, health checks (`/health`), metrics.

### Independent deployability

Services may later run on different servers, environments or clouds. Running everything together (e.g. Docker Compose) is for local development only. Every service must:
- Be self-contained in its own folder: own `Dockerfile`, `.env.example`, database, migrations and tests; it must start on its own.
- Talk to other services only through contracts (HTTP/OpenAPI or events/AsyncAPI). Never import another service's code or access its database.
- Read every address (other services, broker, identity provider, storage, telemetry collector) from environment variables. No `localhost` or container names in code.
- Prefer events over synchronous calls; keep a local, event-fed copy of data owned by another service instead of querying it per request.
- Start even if a dependency is down: retry with backoff, report it in `/health`, use timeouts and circuit breakers on remote calls.
- Use shared packages only for technical utilities and contract types, never for business logic.

## Pattern catalog (use when applicable)

| Problem                                               | Pattern                                   |
|-------------------------------------------------------|-------------------------------------------|
| Isolate data access                                   | Repository                                |
| Orchestrate a use case's logic                        | Use Case / Application Service            |
| Interchangeable algorithms (payments, notifications)  | Strategy                                  |
| Complex or conditional object creation                | Factory / Builder                         |
| Integrate external or legacy APIs                     | Adapter / Anti-Corruption Layer           |
| Add cross-cutting behavior (cache, logging)           | Decorator                                 |
| React to changes without coupling                     | Observer / Domain Events                  |
| Single entry point for clients                        | API Gateway / BFF                         |
| Distributed transactions across services              | Saga (choreography or orchestration)      |
| Publish events consistently with the DB               | Transactional Outbox                      |
| Separate reads and writes with different loads        | CQRS                                      |
| Fault tolerance on remote calls                       | Circuit Breaker, Retry with backoff, Timeout |

Avoid: singletons with global state, god objects, deep inheritance (prefer composition), databases shared between services, and long chains of synchronous calls between services.

## Testing

Tests are part of the task, not an extra step:
- **Every new or changed behavior ships with tests** in the same branch: new use case → unit tests; new adapter/endpoint → integration test; bug fix → a test that reproduces the bug first.
- Cover the happy path, validation errors and relevant edge cases (empty, null, limits, unauthorized).
- Run the affected module's tests before every push, and the full suite before the final push. Failing tests block the final push (**git-workflow** → Tests before pushing).
- Never delete, skip or weaken an existing test to make it pass; if a test is genuinely obsolete, say so and explain why in the PR.
- Tests never use real credentials: use fake values or test-specific env vars (**secrets-management**).

Guidelines:
- Pyramid: many unit tests (domain and use cases), some integration tests (adapters), few end-to-end.
- Independent, deterministic tests whose names describe behavior (`should_reject_expired_token`).
- Arrange–Act–Assert structure. Use test doubles for ports, not for the domain.
- Contract tests between services when consuming another service's API.

## Pre-commit checklist

- [ ] Clear names; small functions with a single responsibility.
- [ ] No dead code, commented-out code or debug logs.
- [ ] No secrets or hardcoded configuration.
- [ ] Errors handled explicitly.
- [ ] New/updated tests for the changed behavior.
- [ ] The domain does not depend on frameworks or infrastructure.
