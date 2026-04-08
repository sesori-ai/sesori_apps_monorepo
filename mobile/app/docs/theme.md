# Sesori Theme Guide

Sesori now uses a local theme layer in [`lib/core/theme`](../lib/core/theme) that was ported from the Zyra/Vespr design system and adapted to Sesori. The visual primitives are owned by this repo, so future brand changes should happen here instead of editing random screens.

## What To Edit

Update brand-facing colors, radii, and font configuration in [`lib/core/theme/sesori_theme_tokens.dart`](../lib/core/theme/sesori_theme_tokens.dart).

Update derived container/surface colors in [`lib/core/theme/sesori_color_schemes.dart`](../lib/core/theme/sesori_color_schemes.dart) only when the token changes require different tonal ramps for light or dark mode.

Update shared button, chip, checkbox, divider, or transition styling in [`lib/core/theme/sesori_theme_shared.dart`](../lib/core/theme/sesori_theme_shared.dart).

## Verify Changes

Run the theme verifier after changing colors, typography, or surfaces:

```sh
cd mobile/app
sh scripts/verify_theme_tokens.sh
flutter test test/core/theme/sesori_theme_test.dart
flutter test test/core/widgets/connection_overlay_widget_test.dart
```

Then run the normal app checks:

```sh
cd mobile/app
flutter test
dart analyze
```

## Guardrails

- Keep Sesori tokens in the Sesori theme files. Do not import Vespr theme classes directly.
- Do not reintroduce glass styling such as `BackdropFilter`, blurred overlays, or frosted cards.
- Prefer changing tokens before editing screen widgets. Most app surfaces should inherit from `ThemeData`.
