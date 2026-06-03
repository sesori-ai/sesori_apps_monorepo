import "package:flutter/material.dart";
import "package:liquid_glass_plus/liquid_glass_plus.dart";
import "package:universal_platform/universal_platform.dart";

import "../../interactions/zyra_tappable.dart";
import "../../theme/zyra_theme.dart";

/// Size variants for [ZyraButtonsIconGlass].
enum ZyraButtonsIconGlassSize {
  /// 48×48 circle — default icon 24px. Matches the Figma app-bar / badge size.
  md,

  /// 64×64 circle — default icon 24px. Matches the larger Figma action size.
  lg,
}

// -- Glass effect tuning ------------------------------------------------------

/// Glass thickness: higher = more pronounced edge refraction.
const double _kGlassThickness = 55.0;

/// Frost intensity: higher = more backdrop blur (frosted appearance).
const double _kGlassFrostIntensity = 5.5;

/// Light reflection intensity along the glass edge.
const double _kGlassLightIntensity = 0.5;

/// Alpha applied to the glass colour overlay tint.
const double _kGlassColorAlpha = 0.3;

/// Saturation boost applied to whatever is refracted behind the glass.
const double _kGlassSaturation = 1.8;

/// Fake-glass (Skia / non-Impeller) refraction edge offset in px.
const double _kGlassFakeRefraction = 8.0;

// -- Disabled-state glass tuning ----------------------------------------------
// The disabled button is dimmed by muting the glass itself rather than wrapping
// it in `Opacity`. The iOS surface is a `BackdropFilter` that samples the
// content behind the button; an `Opacity` < 1 isolates it in a new layer with
// an empty backdrop, so the glass vanishes entirely. Lowering thickness + light
// flattens the edge refraction/specular so the control reads as inactive, while
// the icon falls back to `text-disabled`.

/// Glass thickness in the disabled state — flatter edge refraction.
const double _kGlassDisabledThickness = 18.0;

/// Light reflection intensity in the disabled state — dimmer specular edge.
const double _kGlassDisabledLightIntensity = 0.15;

/// Frost intensity in the disabled state — slightly softened backdrop blur.
const double _kGlassDisabledFrostIntensity = 4.0;

/// A circular "glass" icon button matching the Figma `zyraButtonsIconGlass`
/// component.
///
/// On **iOS** the surface is a real frosted-glass effect rendered with the
/// `liquid_glass_plus` shader (refraction + backdrop blur), tuned to match the
/// Figma component. On **non-iOS** platforms (Android, web,
/// macOS, …) it falls back to a fully-rounded translucent fill using
/// `buttonGlassPrimaryBackground` — the same iOS-only-glass / flat-fallback
/// split used by `ZyraGlassBackground`.
///
/// In both cases a `buttonGlassPrimaryHover` overlay is applied on hover/press
/// via [ZyraTappable]. There is no border or shadow — only the glass/fill.
///
/// Pass `onPressed: null` to render a disabled, non-interactive button: the
/// glass surface is muted (reduced thickness / light / frost so it reads as
/// inactive) and the icon falls back to `text-disabled` (matching the disabled
/// Figma state — e.g. the Step 3 folder-plus affordance shown before the bridge
/// is connected).
///
/// The disabled state deliberately does **not** wrap the button in `Opacity`.
/// The iOS glass is rendered by a `BackdropFilter`, which samples the content
/// behind the button; an `Opacity` < 1 isolates it in a new layer with an empty
/// backdrop and the glass disappears entirely. Dimming is therefore done via the
/// glass settings + icon colour instead.
///
/// Usage:
/// ```dart
/// ZyraButtonsIconGlass(
///   icon: VESPRSolid.gear,
///   onPressed: () => openSettings(),
/// )
/// ```
///
/// Limitation (v1): unlike [ZyraButtonsSolid], this control does not render a
/// keyboard focus ring on web/desktop (it relies solely on [ZyraTappable],
/// which provides hover/press but no [Focus] handling). Touch and pointer
/// interaction work everywhere; add focus styling here if keyboard navigation
/// becomes a requirement on those platforms.
class ZyraButtonsIconGlass extends StatelessWidget {
  const ZyraButtonsIconGlass({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = ZyraButtonsIconGlassSize.md,
    this.iconSize,
    this.iconColor,
    this.semanticLabel,
  });

  /// The glyph rendered at the centre of the button.
  final IconData icon;

  /// Called when the button is tapped. Pass `null` to render in disabled state.
  final VoidCallback? onPressed;

  /// Governs the button diameter (and the default icon size).
  final ZyraButtonsIconGlassSize size;

  /// Overrides the default icon size for the chosen [size].
  final double? iconSize;

  /// Overrides the icon colour. Defaults to `text-primary` when enabled and
  /// `text-disabled` when [onPressed] is `null`.
  final Color? iconColor;

  /// Optional semantics label describing the action for screen readers.
  final String? semanticLabel;

  double get _diameter => switch (size) {
    ZyraButtonsIconGlassSize.md => 48.0,
    ZyraButtonsIconGlassSize.lg => 64.0,
  };

  double get _defaultIconSize => switch (size) {
    ZyraButtonsIconGlassSize.md => 24.0,
    ZyraButtonsIconGlassSize.lg => 24.0,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.zyra.colors;
    final isDisabled = onPressed == null;
    final resolvedIconColor = iconColor ?? (isDisabled ? colors.textDisabled : colors.textPrimary);

    final button = ZyraTappable.stateAware(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(ZyraRadius.full),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)) {
          return colors.buttonGlassPrimaryHover;
        }
        return null;
      }),
      containerBuilder: ({required Widget child, required Set<WidgetState> state}) {
        // iOS: real frosted glass via the liquid_glass_plus shader. The icon
        // (`child`) renders on top of the glass (glassContainsChild: false) so
        // it stays crisp. `.withOwnLayer` makes the button self-contained — no
        // ancestor LiquidGlassLayer is required at the call site.
        if (UniversalPlatform.isIOS) {
          return LiquidGlass.withOwnLayer(
            shape: const LiquidOval(),
            settings: LiquidGlassSettings(
              thickness: isDisabled ? _kGlassDisabledThickness : _kGlassThickness,
              frostIntensity: isDisabled ? _kGlassDisabledFrostIntensity : _kGlassFrostIntensity,
              lightIntensity: isDisabled ? _kGlassDisabledLightIntensity : _kGlassLightIntensity,
              glassColor: colors.bgDisabled.withValues(alpha: _kGlassColorAlpha),
              saturation: _kGlassSaturation,
              fakeGlassConfigs: const FakeGlassConfigs(refraction: _kGlassFakeRefraction),
            ),
            child: child,
          );
        }

        // Non-iOS: translucent fill fallback (the original v1 surface).
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.buttonGlassPrimaryBackground,
            shape: BoxShape.circle,
          ),
          child: child,
        );
      },
      childBuilder: ({required Set<WidgetState> state}) {
        return SizedBox.square(
          dimension: _diameter,
          child: Center(
            child: Icon(
              icon,
              size: iconSize ?? _defaultIconSize,
              color: resolvedIconColor,
              semanticLabel: semanticLabel,
            ),
          ),
        );
      },
    );

    return button;
  }
}
