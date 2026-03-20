# sesori_flutter

Flutter UI shell for the Sesori mobile client. Provides screens, widgets, routing, and platform adapter implementations. All business logic lives in [`sesori_dart_core`](../sesori_dart_core/).

See the [root README](../README.md) for the full monorepo overview.

## Run

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Tech stack

| Concern | Library |
|---------|---------|
| State management (widgets) | `flutter_bloc` (`BlocProvider`, `context.watch`) |
| Dependency injection | `get_it` + `injectable` |
| Navigation | `go_router` |
| Relay encryption (accelerated) | `cryptography_flutter` |
| Secure storage | `flutter_secure_storage` |
| Deep links | `app_links` |
| URL launching | `url_launcher` |
| Audio recording | `record` |
| Wake lock | `wakelock_plus` |
| Markdown rendering | `flutter_markdown_plus` |
