# sesori_auth — Authentication Package

Standalone pure Dart package encapsulating all authentication concerns: token lifecycle, OAuth flow, and authenticated HTTP. Zero Flutter dependency.

See [`../AGENTS.md`](../AGENTS.md) for shared conventions (architecture layering, DI, testing, error handling).

## Public API (exported from barrel file)

Only these types are exported. Everything else is internal (`lib/src/`).

### Interfaces

- `AuthTokenProvider` — read-only access to a fresh token (`getFreshAccessToken()`). Injected by consumers that need a raw token string (e.g. relay WebSocket auth).
- `OAuthFlowProvider` — drives OAuth login: PKCE generation, auth URL fetch, code exchange. Injected by `LoginCubit`.
- `AuthSession` — auth state stream, getCurrentUser, logout. Injected by `AuthRedirectService`, `ConnectionOverlayCubit`.

### Classes

- `AuthenticatedHttpApiClient` — HTTP decorator that auto-injects Bearer token and retries on 401. Returns `http.Response`. Injected by authenticated API classes (e.g. `VoiceApi`).

### Types

- `AuthState` (freezed sealed class) — `unauthenticated`, `authenticating`, `authenticated`, `failed`
- `AuthProvider` enum — `github`, `google`
- `SecureStorage` abstract interface — platform-agnostic key-value secure storage
- `authBaseUrl` constant — auth server base URL

## Internal Architecture

```
lib/src/
├── auth_config.dart        authBaseUrl, AuthProvider enum
├── auth_manager.dart       AuthManager — single owner of auth lifecycle (NOT exported)
├── client/
│   └── authenticated_http_api_client.dart
├── di/
│   ├── auth_module.dart    Interface bindings (AuthManager → 3 interfaces)
│   ├── injection.dart      configureAuthDependencies()
│   └── injection.config.dart (generated)
├── interfaces/
│   ├── auth_session.dart
│   ├── auth_token_provider.dart
│   └── oauth_flow_provider.dart
├── models/
│   └── auth_state.dart     (+ .freezed.dart)
├── platform/
│   └── secure_storage.dart
└── storage/
    ├── oauth_storage_service.dart   (NOT exported)
    └── token_storage_service.dart   (NOT exported)
```

## Key Design Decisions

- **Single writer**: Only `AuthManager` writes tokens. No external class can clear, refresh, or store tokens.
- **Package boundary enforcement**: Internal types (`AuthManager`, storage services) are NOT exported. The `implementation_imports` lint prevents cross-package `src/` imports.
- **No relay knowledge**: Auth package knows nothing about relay, WebSocket, or room keys. Logout emits `AuthState.unauthenticated` — `ConnectionService` reacts by disconnecting.
- **Singleflight refresh**: Concurrent token refresh requests are coalesced (`_activeRefresh ??= ...`). Only one refresh HTTP call per expiry window.
- **Proactive refresh**: Tokens refreshed before expiry (30s hard threshold, 90s background soft threshold).

## Conventions

- Pure Dart only — NO `package:flutter*` imports
- Uses `package:http` directly for auth HTTP calls (NOT core's `HttpApiClient`)
- `@lazySingleton` for `AuthManager` and storage classes
- Positional constructor parameters for injectable auto-wiring
- Double quotes for all strings

## DI Registration

`configureAuthDependencies(getIt)` registers:
- `AuthManager` (concrete, internal)
- `AuthTokenProvider` → `AuthManager`
- `OAuthFlowProvider` → `AuthManager`
- `AuthSession` → `AuthManager`
- `AuthenticatedHttpApiClient`
- `TokenStorageService` (internal)
- `OAuthStorageService` (internal)

**Prerequisite**: `SecureStorage` must be registered before auth DI runs (Flutter registers `FlutterSecureStorageAdapter`).

## Testing

- Use `package:test`, NOT `package:flutter_test`
- Use `mocktail` for mocks
- Mock `http.Client`, `TokenStorageService`, `OAuthStorageService` in AuthManager tests
- Consumers mock the interfaces: `MockAuthTokenProvider`, `MockOAuthFlowProvider`, `MockAuthSession`
