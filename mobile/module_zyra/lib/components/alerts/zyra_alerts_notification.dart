import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/zyra_tappable.dart";
import "../../theme/zyra_theme.dart";

/// Visual variant for [ZyraAlertsNotification].
///
/// Each variant pairs a leading icon with an accent colour used for the
/// radial gradient overlay and the icon tint.
enum ZyraAlertsNotificationVariant {
  /// Error / failure — red circle-exclamation icon, error-red gradient.
  error,
}

/// A dark, gradient-tinted alert notification matching the Figma
/// `zyraAlertsNotifications` component.
///
/// The component renders with a fixed dark background regardless of the
/// app's brightness — the gradient overlay and white-alpha text colours
/// are designed for a dark surface only.
///
/// Usage:
/// ```dart
/// ZyraAlertsNotification(
///   title: 'Authentication failed',
///   message: 'The credentials returned by Google could not be verified. '
///       'Please try again.',
///   onClose: () => setState(() => _showError = false),
/// )
/// ```
///
/// Passing `onClose: null` hides the close button.
class ZyraAlertsNotification extends StatelessWidget {
  const ZyraAlertsNotification({
    super.key,
    required this.title,
    this.message,
    this.onClose,
    this.variant = ZyraAlertsNotificationVariant.error,
  });

  /// Bold headline text shown on the first line.
  final String title;

  /// Optional supporting description shown below [title]. When `null`,
  /// only the title is rendered.
  final String? message;

  /// Called when the user taps the close button. When `null`, the close
  /// button is not rendered.
  final VoidCallback? onClose;

  /// Controls the leading icon and accent colour. Currently only
  /// [ZyraAlertsNotificationVariant.error] is defined.
  final ZyraAlertsNotificationVariant variant;

  // Solid background fill — `rgb(24, 25, 27)`. Not a semantic token because
  // the alert is always rendered on a dark surface regardless of theme.
  static const Color _backgroundColor = Color(0xFF18191B);

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final accentColor = _resolveAccentColor(colors: zyra.colors);
    final iconData = _resolveIcon();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(ZyraRadius.x2l),
        border: Border.all(color: zyra.colors.borderTertiary),
        boxShadow: zyra.shadows.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZyraRadius.x2l),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      // Centre near the top edge — matches Figma's gradient
                      // transform that places the radial origin at top-centre.
                      center: Alignment.topCenter,
                      radius: 1.0,
                      colors: [
                        Colors.black.withValues(alpha: 0.1 * 0.3),
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
                ZyraSpacing.xl,
                ZyraSpacing.x2l,
                ZyraSpacing.xl,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconData, size: 22, color: accentColor),
                  const SizedBox(width: ZyraSpacing.lg),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
            if (onClose != null)
              PositionedDirectional(
                top: 7,
                end: 7,
                child: _CloseButton(onPressed: onClose),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Builder(
      builder: (context) {
        final textTheme = context.zyra.textTheme;
        final messageText = message;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: textTheme.textSm.bold.copyWith(color: Colors.white),
            ),
            if (messageText != null) ...[
              const SizedBox(height: ZyraSpacing.lg),
              Text(
                messageText,
                style: textTheme.textSm.medium.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _resolveAccentColor({required ZyraColors colors}) => switch (variant) {
    ZyraAlertsNotificationVariant.error => colors.fgErrorSecondary,
  };

  IconData _resolveIcon() => switch (variant) {
    ZyraAlertsNotificationVariant.error => TablerOutline.alert_circle,
  };
}

/// Round, translucent close button rendered in the alert's top-trailing
/// corner. Tap target is 36×36 (8px padding around a 20px icon).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ZyraTappable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(ZyraRadius.full),
      containerBuilder: (child) => Padding(
        padding: const EdgeInsetsDirectional.all(ZyraSpacing.md),
        child: child,
      ),
      child: Icon(
        TablerOutline.x,
        size: 20,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}
