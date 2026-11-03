# Sesori Shared (Dart)

Pure Dart library — crypto primitives + protocol types shared by the bridge,
mobile app, desktop core, and shared app UI. No Flutter dependency. Works in
native binaries and Flutter apps.

## Error Handling

**Never silently swallow.** The target is a `catch` that discards an error and continues with no trace (`catch (e) { /* no-op */ }`). A handler that swallows and continues (no-op/best-effort cleanup included) must log, and a catch-all (`on Object catch`/`catch (e)`) especially, since the cause is unknown. But do NOT add a redundant log when the catch already surfaces the failure — rethrows, throws a typed exception, or returns/yields an explicit failure the caller renders — that just double-logs. When you log a caught error, pass it as the logger argument (`Log.w("msg", error, stackTrace)`), don't string-interpolate it.

## STRUCTURE

```
lib/
├── sesori_shared.dart   Barrel export of the public API
└── src/
    ├── crypto/          RelayCryptoService (X25519, HKDF, XChaCha20), SessionEncryptor, SHA-256
    ├── protocol/        Relay framing, RelayMessage, RelayNoticeMessage and RelayControlMessage, close codes,
    │                    desktop↔bridge ControlMessage, BridgeSupervisedExitCode
    ├── models/
    │   ├── auth/        Auth-server API models (login, account, bridge registration, …)
    │   └── sesori/      Backend-neutral client↔bridge wire models (sessions, projects,
    │                    messages, plugins, MCP, settings, …)
    ├── auth/            JWT claim parsing
    ├── transcript/      Prompt-turn and transcript search helpers
    ├── voice/           Dictation and project-glossary types
    ├── notifications/   Session notification identifiers
    ├── search/          Title matching
    ├── reporting/       Failure reporter interface
    ├── concurrency/     Small async helpers
    ├── constants/       SSE constants
    ├── converters/      JSON converters
    └── extensions/      Dart extensions
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add message variant | `src/protocol/messages.dart` | Add to the RelayMessage sealed class, run build_runner |
| Modify encryption | `src/crypto/crypto_service.dart` | HKDF info string: `"sesori-relay-v1"` |
| Add a client↔bridge wire model | `src/models/sesori/` | Backend-neutral only; backend models belong in their plugin. Freezed sealed class, add export to barrel |
| Change wire format | `src/protocol/framing.dart` | Version byte 0x01, 24-byte nonce prefix |

## CONVENTIONS

- **Freezed sealed classes**: All model/protocol types use `sealed class` (NOT `abstract class`) for exhaustive switch
- **build.yaml**: `format: false`, `map: false`, `when: false` — reduced generated code
- **Null keys omitted from wire payloads**: `build.yaml` sets `json_serializable` `include_if_null: false`, so nullable fields are dropped from `toJson()` output by default. Do **NOT** add `@JsonKey(includeIfNull: false)` explicitly — it is already the default here. (Decoding is unaffected: a missing key deserializes to `null`.)
- **Strict analysis**: `strict-casts`, `strict-inference`, `strict-raw-types` all ON
- **Barrel export**: All public API re-exported from `lib/sesori_shared.dart`
- **Legacy plugin attribution**: Missing `pluginId` fields default to `opencode`
  because released peers without attribution could only target OpenCode. This
  is a narrow historical wire default, not a general licence for backend
  behavior or capabilities in shared models.
- **Platform-derived DTOs**: platform adapters gather facts through Flutter
  plugins or `dart:io`; shared builders accept plain values and own common wire
  schema normalization such as trimming, fallbacks, and length limits. Never
  import platform packages into this module or duplicate those shared rules in
  each product.
- **Line width**: 120 characters
- **Request/response models for bridge handlers** — every bridge handler that accepts or returns a JSON body must have a Freezed model here (e.g. `CreateSessionRequest`, `OpenProjectRequest`). Models use `@Freezed(fromJson: true, toJson: true)`. Bridge handlers parse with `fromJson()`, mobile services serialize with `toJson()`.

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
```
