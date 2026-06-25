import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

/// Visual variant for [PregoPopupAlertsNotifications].
///
/// Each variant pairs a leading icon with an accent colour used for the
/// radial gradient overlay and the icon tint.
enum PregoPopupAlertsNotificationsVariant {
  /// Error / failure — red circle-exclamation icon, error-red gradient.
  error,
}

/// A dark, gradient-tinted alert notification matching the Figma
/// `pregoPopupAlertsNotifications` component.
///
/// The component renders with a fixed dark background regardless of the
/// app's brightness — the gradient overlay and white-alpha text colours
/// are designed for a dark surface only.
///
/// Usage:
/// ```dart
/// PregoPopupAlertsNotifications(
///   title: 'Authentication failed',
///   message: 'The credentials returned by Google could not be verified. '
///       'Please try again.',
///   onClose: () => setState(() => _showError = false),
/// )
/// ```
///
/// Passing `onClose: null` hides the close button.
class PregoPopupAlertsNotifications extends StatelessWidget {
  const PregoPopupAlertsNotifications({
    super.key,
    required this.title,
    this.message,
    this.onClose,
    this.variant = PregoPopupAlertsNotificationsVariant.error,
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
  /// [PregoPopupAlertsNotificationsVariant.error] is defined.
  final PregoPopupAlertsNotificationsVariant variant;

  // Solid background fill — `rgb(24, 25, 27)`. Not a semantic token because
  // the alert is always rendered on a dark surface regardless of theme.
  static const Color _backgroundColor = Color(0xFF18191B);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final accentColor = _resolveAccentColor(colors: prego.colors);
    final iconData = _resolveIcon();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(PregoRadius.x2l),
        border: Border.all(color: prego.colors.borderTertiary),
        boxShadow: prego.shadows.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PregoRadius.x2l),
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
                PregoSpacing.xl,
                PregoSpacing.xl,
                PregoSpacing.x2l,
                PregoSpacing.xl,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconData, size: 22, color: accentColor),
                  const SizedBox(width: PregoSpacing.lg),
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
        final textTheme = context.prego.textTheme;
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
              const SizedBox(height: PregoSpacing.lg),
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

  Color _resolveAccentColor({required PregoColors colors}) => switch (variant) {
    PregoPopupAlertsNotificationsVariant.error => colors.fgErrorSecondary,
  };

  IconData _resolveIcon() => switch (variant) {
    PregoPopupAlertsNotificationsVariant.error => TablerRegular.alert_circle,
  };
}

/// Round, translucent close button rendered in the alert's top-trailing
/// corner. Tap target is 36×36 (8px padding around a 20px icon).
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PregoTappable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(PregoRadius.full),
      containerBuilder: (child) => Padding(
        padding: const EdgeInsetsDirectional.all(PregoSpacing.md),
        child: child,
      ),
      child: Icon(
        TablerRegular.x,
        size: 20,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }
}
