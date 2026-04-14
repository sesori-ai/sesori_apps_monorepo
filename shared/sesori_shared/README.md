# Sesori Shared

Shared Dart package containing crypto primitives, relay protocol types, data models, and concurrency utilities. Used by both the bridge workspace and the mobile workspace in this monorepo. Changes here affect both consumers.

## Crypto

**`RelayCryptoService`**

- X25519 key pair generation
- HKDF-SHA256 session key derivation
- XChaCha20-Poly1305 encrypt/decrypt

**`SessionEncryptor`**

Stateful encryptor bound to a derived session key. Wraps `RelayCryptoService` for use within an established relay session.

## Protocol

**`RelayMessage`**

Freezed sealed class with 11 variants:

| Variant | Direction |
|---------|-----------|
| `request` | Mobile to bridge |
| `response` | Bridge to mobile |
| `sseEvent` | Bridge to mobile |
| `sseSubscribe` | Mobile to bridge |
| `sseUnsubscribe` | Mobile to bridge |
| `keyExchange` | Both |
| `ready` | Relay to client |
| `resume` | Client to relay |
| `resumeAck` | Relay to client |
| `rekeyRequired` | Relay to client |
| `auth` | Client to relay |

**`frame` / `unframe`**

Binary WebSocket framing with a version byte prefix. Used by both ends of the relay connection.

Protocol constants (message type strings, role identifiers) and close codes are also exported.

## Data Models

**Auth**

`AuthUser`, `AuthResponse`, `AuthUrlResponse`, `AuthMeResponse`, `LogoutResponse`

**Sesori**

`Project`, `Session`, `Message`, `MessagePart`, `MessageWithParts`, `Question`, `AgentInfo`, `AgentMode`, `ProviderInfo`, `SessionStatus`, `HealthResponse`, `FileDiff`, `ProjectActivitySummary`, `SesoriSseEvent`

## Concurrency

`ConcurrentCache` — async-safe cache with per-key locking to prevent duplicate concurrent fetches.

`EventQueue` — ordered async event dispatcher.

`SingleTaskIsolate` / `MultiTaskIsolate` — typed isolate wrappers with persistent and transient pool variants. Constructed via factory constructors that select the right implementation based on `minPoolSize`/`maxPoolSize`.

## Adding as a Dependency

```yaml
dependencies:
  sesori_shared:
    path: ../sesori_shared
```

Then run `dart pub get`.

## Notes

Pure Dart — no Flutter dependency. Works in any Dart environment including native binaries and Flutter apps.

Requires Dart 3.8.0 or later (sealed class support, `freezed` generated output).

## License

This package is source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`).

You may use it for permitted purposes, but you may not use it to launch a competing product or service.

On the second anniversary of the date this version is made available, it automatically becomes available under Apache License 2.0.

See [LICENSE](LICENSE) for the full terms.
