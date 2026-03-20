# Sesori Mobile — Monorepo

Multi-package Dart/Flutter repository for the Sesori mobile ecosystem.

## Repository Structure

```
sesori_auth/        Pure Dart package — authentication, token lifecycle, OAuth flow
sesori_dart_core/   Pure Dart package — business logic, services, cubits, models
sesori_flutter/     Flutter app — UI screens, widgets, routing, platform adapters
```

Authentication is fully encapsulated in `sesori_auth` behind narrow interfaces (`AuthTokenProvider`, `OAuthFlowProvider`, `AuthSession`). All non-UI business logic lives in `sesori_dart_core`. The Flutter app is a thin shell that provides platform implementations and UI.

## Shared Conventions

- Dart SDK `^3.11.1`
- Double quotes for all strings consistently
- `http` package for networking (NOT dio)
- `rxdart` for reactive streams (`BehaviorSubject`)
- `get_it` + `injectable` for dependency injection
  - Services: `@lazySingleton` — single shared instance
  - Cubits: NOT registered in DI — constructed manually in `BlocProvider(create:)`
  - Use positional constructor parameters for injectable auto-wiring
- `freezed` for immutable models — always `sealed class`, `build.yaml` options: `format: false`, `map: false`, `when: false`
- Errors always logged (`loge`/`logw` from `sesori_dart_core`), never silently swallowed

## Architecture Layering

```
http.Client <- AuthenticatedHttpApiClient/HttpApiClient <- XyzApi <- 0+ Repository <- 1+ Service <- Cubit <- Widget
```

- **DO NOT** inject/use `http.Client` into services/repositories/widgets — only API clients get direct access
- **ALL** API calls go through an `XyzApi` class
- **Authenticated API calls** use `AuthenticatedHttpApiClient` (from `sesori_auth`) which auto-injects Bearer tokens and handles 401 retry
- **Repository** layer only when mixing multiple data sources
- **Service** layer provides simple APIs for cubits
- **Cubit** contains UI display logic (lives in `sesori_dart_core`)
- **Widget** consumes cubits via `BlocProvider` (lives in `sesori_flutter`)

## Authentication Architecture

Auth is a separate package (`sesori_auth`) with package-boundary enforcement. Internal types are not exported.

- **`AuthManager`** (internal) — single owner of token lifecycle, OAuth flow, and auth state. Implements all 3 interfaces.
- **`AuthTokenProvider`** — read-only fresh token access. Injected by `ConnectionService` for relay WebSocket auth.
- **`OAuthFlowProvider`** — drives OAuth login (PKCE + code exchange). Injected by `LoginCubit`.
- **`AuthSession`** — auth state stream + logout + getCurrentUser. Injected by `AuthRedirectService`, `ConnectionOverlayCubit`.
- **`AuthenticatedHttpApiClient`** — HTTP decorator that adds Bearer token + 401 retry. Injected by `VoiceApi`.

DI initialization order: **Flutter platform** (SecureStorage, etc.) → **`configureAuthDependencies`** → **`configureCoreDependencies`**

## Testing

- Unit test all non-widget code. Use `mocktail`.
- Never use `getIt<...>()` outside widget code — inject via constructor for testability
- Core package tests use `package:test`; Flutter app tests use `package:flutter_test`

## Per-Package Details

- [`sesori_auth/AGENTS.md`](sesori_auth/AGENTS.md) — auth package conventions, public API surface
- [`sesori_dart_core/AGENTS.md`](sesori_dart_core/AGENTS.md) — pure Dart conventions, package structure
- [`sesori_flutter/AGENTS.md`](sesori_flutter/AGENTS.md) — Flutter-specific conventions, UI patterns
