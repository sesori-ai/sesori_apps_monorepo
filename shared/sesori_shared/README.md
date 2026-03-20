# Sesori Shared

Shared Dart package containing the crypto primitives and protocol types for the Sesori relay system. Used by both `sesori_bridge_dart` and `sesori_mobile` to avoid duplicating core logic.

## What it exports

**Crypto**

- `RelayCryptoService` — X25519 key generation, HKDF-SHA256 key derivation, XChaCha20-Poly1305 encryption/decryption
- `SessionEncryptor` — stateful encryptor tied to a derived session key

**Protocol**

- `RelayMessage` — Freezed sealed class with 11 message variants (`request`, `response`, `sseEvent`, `sseSubscribe`, `sseUnsubscribe`, `keyExchange`, `ready`, `resume`, `resumeAck`, `rekeyRequired`, `auth`)
- `frame` / `unframe` — binary framing with version byte prefix for WebSocket transport
- Protocol constants (message type strings, role identifiers)
- Close codes

## Adding as a dependency

In your `pubspec.yaml`:

```yaml
dependencies:
  sesori_shared:
    path: ../sesori_shared
```

Then run `dart pub get`.

## Notes

Pure Dart — no Flutter dependency. Works in any Dart environment including native binaries and Flutter apps.

The package requires Dart 3.8+ for sealed class support and the `freezed` code generation output.
