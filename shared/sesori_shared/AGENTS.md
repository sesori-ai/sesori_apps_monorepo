# Sesori Shared (Dart)

Pure Dart library — crypto primitives + protocol types shared by `sesori_bridge_dart` and `sesori_mobile`. No Flutter dependency. Works in native binaries and Flutter apps.

## STRUCTURE

```
lib/
├── sesori_shared.dart         Barrel export (24 exports — crypto, models, protocol)
└── src/
    ├── crypto/
    │   ├── crypto_service.dart      RelayCryptoService — X25519 keygen, HKDF derivation, XChaCha20 encrypt/decrypt
    │   └── session_encryptor.dart   SessionEncryptor — stateful encryptor tied to derived session key
    ├── models/
    │   ├── auth/                    Auth models — AuthResponse, AuthUser, LogoutUrlResponse (Freezed)
    │   └── opencode/               OpenCode models — Session, Project, Message, AgentInfo, Provider, etc. (Freezed)
    └── protocol/
        ├── close_codes.dart         WebSocket close codes for relay protocol
        ├── constants.dart           Role strings, message type identifiers
        ├── framing.dart             frame()/unframe() — binary wire format with version byte
        └── messages.dart            RelayMessage sealed class — 11 variants (request, response, sseEvent, keyExchange, etc.)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add message variant | `src/protocol/messages.dart` | Add to RelayMessage sealed class, run build_runner |
| Modify encryption | `src/crypto/crypto_service.dart` | HKDF info string: `"sesori-relay-v1"` |
| Add OpenCode model | `src/models/opencode/` | Freezed sealed class, add export to barrel |
| Change wire format | `src/protocol/framing.dart` | Version byte 0x01, 24-byte nonce prefix |

## CONVENTIONS

- **Freezed sealed classes**: All model/protocol types use `sealed class` (NOT `abstract class`) for exhaustive switch
- **build.yaml**: `format: false`, `map: false`, `when: false` — reduced generated code
- **Strict analysis**: `strict-casts`, `strict-inference`, `strict-raw-types` all ON
- **Barrel export**: All public API re-exported from `lib/sesori_shared.dart`
- **Line width**: 120 characters

## ANTI-PATTERNS

- **NEVER use raw DH output as cipher key** — always derive via HKDF-SHA256 with info `"sesori-relay-v1"`
- **NEVER edit `.freezed.dart` or `.g.dart`** — regenerate with build_runner
- **NEVER add Flutter dependency** — this is a pure Dart package

## COMMANDS

```bash
dart pub get                                                         # Install deps
dart run build_runner build --delete-conflicting-outputs             # Regenerate .freezed.dart / .g.dart
dart test                                                            # Run tests
dart analyze                                                         # Static analysis
make publish                                                         # Publish to pub.dev
```
