import "package:flutter/material.dart";

import "../../theme/zyra_theme.dart";
import "../buttons/zyra_buttons_solid.dart";

/// Visual variant for [ZyraInlineBanner].
///
/// Each variant pairs an accent colour (used for the leading icon and the
/// radial gradient overlay) with the fill colour of the optional trailing
/// action button.
enum ZyraInlineBannerVariant {
  /// Warning / attention — amber accent, warning-orange action button.
  warning,
}

/// Configuration for [ZyraInlineBanner]'s optional trailing action button.
///
/// Rendered as a pill button tinted with the variant's accent colour. Pass
/// `null` for [ZyraInlineBanner.action] to render a banner with no button.
class ZyraInlineBannerAction {
  const ZyraInlineBannerAction({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Button label.
  final String label;

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// Optional icon placed before the [label].
  final IconData? icon;
}

/// A full-width, single-row inline banner — the inline form of the Figma
/// `zyraAlertsNotifications` component (the variant with the supporting text
/// and close button hidden and an inline action shown).
///
/// Unlike [ZyraAlertsNotification] — a dark, always-on-dark notification card —
/// this banner renders on an adaptive surface ([ZyraColors.bgPrimary]) with
/// adaptive text ([ZyraColors.textPrimary]) and a warm accent gradient on top,
/// so it reads correctly in both light and dark themes. It is intended to be
/// pinned inline above the navigation bar and can be shown anywhere in the app.
///
/// Usage:
/// ```dart
/// ZyraInlineBanner(
///   title: 'Bridge Offline',
///   icon: TablerOutline.wifi,
///   action: ZyraInlineBannerAction(
///     label: 'Reconnect',
///     icon: TablerOutline.rotate_clockwise,
///     onPressed: _reconnect,
///   ),
/// )
/// ```
class ZyraInlineBanner extends StatelessWidget {
  const ZyraInlineBanner({
    super.key,
    required this.title,
    this.icon,
    this.variant = ZyraInlineBannerVariant.warning,
    this.action,
  });

  /// Bold headline text. Renders on a single row; long titles ellipsize.
  final String title;

  /// Optional leading icon tinted with the variant accent. When `null`, no
  /// icon is shown.
  final IconData? icon;

  /// Controls the accent colour and the action button fill.
  final ZyraInlineBannerVariant variant;

  /// Optional trailing action button. When `null`, only the title is shown.
  final ZyraInlineBannerAction? action;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final accentColor = _resolveAccentColor(colors: zyra.colors);
    final bannerAction = action;
    final iconData = icon;

    // Wrapped in a transparent [Material] so the title's [Text] inherits a
    // proper default text style (and ink context) even when the banner is
    // placed outside a [Scaffold]/[Material] — e.g. directly in an overlay
    // stack. Without it, text falls back to the debug-underlined style.
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: zyra.colors.fgPrimary,
          boxShadow: zyra.shadows.xs,
        ),
        child: Stack(
          children: [
            // Warm accent overlay — a faint dark centre fading out to the
            // variant accent at the edges, composited at 30% opacity to match
            // the Figma radial gradient. Sits over [bgPrimary] so it adapts to
            // the surface brightness.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // center: Alignment.center,
                      // radius: 1.0,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        accentColor.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ZyraSpacing.xl,
                ZyraSpacing.lg,
                ZyraSpacing.x2l,
                ZyraSpacing.lg,
              ),
              child: Row(
                children: [
                  if (iconData != null) ...[
                    Icon(iconData, size: 22, color: accentColor),
                    const SizedBox(width: ZyraSpacing.lg),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: zyra.textTheme.textSm.bold.copyWith(
                        color: zyra.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (bannerAction != null) ...[
                    const SizedBox(width: ZyraSpacing.lg),
                    ZyraButtonsSolid(
                      label: bannerAction.label,
                      leadingIcon: bannerAction.icon,
                      hierarchy: ZyraButtonsSolidHierarchy.primary,
                      size: ZyraButtonsSolidSize.sm,
                      tone: ZyraButtonsSolidTone.warning,
                      onPressed: bannerAction.onPressed,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveAccentColor({required ZyraColors colors}) => switch (variant) {
    ZyraInlineBannerVariant.warning => colors.fgWarningPrimary,
  };
}
