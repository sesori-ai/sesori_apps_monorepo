# Sesori Auth (sesori_auth)

Authentication package handling OAuth flow, token lifecycle, and authenticated HTTP client. Pure Dart — no Flutter dependency.

See the [root README](../README.md) for the full monorepo overview.

## Key Components

**`AuthManager`**

Central auth coordinator. Implements `AuthTokenProvider`, `OAuthFlowProvider`, and `AuthSession`.

- `authStateStream` — `Stream<AuthState>` broadcasting current auth state
- `currentState` — synchronous snapshot of the current `AuthState`
- `getFreshAccessToken({Duration minTtl, bool forceRefresh})` — returns a valid access token, refreshing proactively when TTL drops below 90 seconds and blocking when below `minTtl` (default 30s). Deduplicates concurrent refresh calls.
- `getAuthorizationUrl(OAuthProvider provider, String redirectUri)` — generates PKCE verifier/challenge, persists them, and returns the provider's authorization URL
- `exchangeCode({String code, String state, String redirectUri})` — completes the PKCE flow, persists tokens, emits `AuthState.authenticated`
- `getCurrentUser()` — fetches `/auth/me` with a fresh token
- `invalidateAllSessions()` — calls `/auth/logout`, clears all stored tokens, emits `AuthState.unauthenticated`
- `logoutCurrentDevice()` — clears local tokens only, emits `AuthState.unauthenticated`

**`AuthenticatedHttpApiClient`**

Decorates `HttpApiClient` with bearer token injection and automatic one-time retry on 401. Implements `SafeApiClient` (GET, POST, PATCH, DELETE, multipart POST).

**`TokenStorageService` / `OAuthStorageService`**

Internal services for persisting access/refresh tokens and PKCE state via the `SecureStorage` platform interface.

**`AuthState`**

Freezed sealed class with four variants:

```dart
AuthState.unauthenticated()
AuthState.authenticating()
AuthState.authenticated(user: AuthUser)
AuthState.failed(error: String)
```

**`ApiResponse<T>`**

Freezed sealed class wrapping all HTTP results:

```dart
ApiResponse.success(T data)   // SuccessResponse<T>
ApiResponse.error(ApiError)   // ErrorResponse<T>
```

**`ApiError`**

Freezed sealed class for typed error handling:

| Variant | When |
|---------|------|
| `JsonParsingError` | Response body failed to parse |
| `DartHttpClientError` | Network-level failure |
| `NonSuccessCodeError` | HTTP status outside 2xx |
| `NotAuthenticatedError` | No valid token available |
| `GenericError` | Unclassified failure |

## DI Registration

```dart
import "package:sesori_auth/sesori_auth.dart";

// Phase 2 of 3-phase init — after platform adapters, before core:
configureAuthDependencies(getIt);
```

Platform adapters (`SecureStorage`, `http.Client`) must be registered before calling this. `configureCoreDependencies` must be called after.

## Testing

```bash
dart test
```

Pure Dart — no Flutter toolchain needed.
