import "package:flutter/foundation.dart";

/// Whether the design system should render real liquid-glass shader effects on
/// the current platform.
///
/// Liquid glass is cheap on Apple's Metal pipeline but expensive on Android: the
/// backdrop blur plus the per-frame shader morph cost real GPU time and visibly
/// jank, especially while a [GlassMenu] is morphing open over scrolling content.
/// So the design system renders flat, solid fallbacks on Android instead.
///
/// Keyed on [defaultTargetPlatform] (not `dart:io`'s `Platform`) so it honours
/// [debugDefaultTargetPlatformOverride] and can be driven from widget tests —
/// the same signal Flutter and `liquid_glass_widgets` themselves branch on.
///
/// Pass [platform] only to override the resolved platform (e.g. in tests);
/// callers normally invoke it with no arguments.
bool glassEffectsEnabled({TargetPlatform? platform}) =>
    (platform ?? defaultTargetPlatform) != TargetPlatform.android;
