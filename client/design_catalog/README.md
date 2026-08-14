# Sesori Design Catalog

Free, interactive Flutter component catalog built with Widgetbook OSS. It is a
workspace package that depends on `theme_prego`, not on either product shell or
business modules.

## Work on a component

1. Start the catalog with `flutter run -d chrome` from this directory.
2. Open **Prego → Solid button → Playground** and adjust its knobs for size,
   hierarchy, tone, interaction state, icons, and width.
3. Edit the production component in
   `../module_prego/lib/components/buttons/prego_buttons_solid.dart`.
4. Hot reload, then inspect **All curated states** in both Prego themes and the
   available iOS/Android viewports.
5. Add a curated scenario when the change creates a meaningful product state,
   then regenerate the manifest.

## Commands

```bash
dart run tool/generate_manifest.dart
dart run tool/generate_manifest.dart --check
dart analyze --fatal-infos
flutter test
flutter build web --release
```

`web/catalog_manifest.json` is generated from the same typed scenario registry
that drives Widgetbook navigation and the all-states matrix. Do not edit it by
hand.

The catalog must use synthetic examples only. It must not import production
authentication, routing, relay, analytics, credentials, or service setup.
