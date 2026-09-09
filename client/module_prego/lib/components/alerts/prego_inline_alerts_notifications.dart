import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";
import "../loaders/prego_activity_indicator.dart";

/// Visual type for [PregoInlineAlertsNotifications] — the Figma component's
/// `Type` property.
///
/// Each value selects the leading status icon, the warm accent gradient, and
/// the fill of the primary action button.
enum PregoInlineAlertsNotificationsType() {
  /// Neutral / informational — `circle-info` icon, brand-blue action button,
  /// neutral surface.
  info,

  /// Success / confirmation — green `circle-check` icon, success-green action
  /// button, green accent glow.
  success,

  /// Warning / attention — amber `triangle-exclamation` icon, warning-amber
  /// action button, amber accent glow.
  warning,

  /// Error / failure — red `circle-exclamation` icon, error-red action button,
  /// red accent glow.
  error,

  /// In-progress — a spinner replaces the leading icon, the primary action
  /// renders in the "primary alt" style on the neutral surface (as for [info]).
  loading,
}

/// Configuration for one of [PregoInlineAlertsNotifications]'s action buttons.
///
/// Used for both the primary ("Learn more") and secondary buttons. Pass `null`
/// for the corresponding [PregoInlineAlertsNotifications] field to omit a
/// button.
class const PregoInlineAlertsNotificationsAction({
  /// Button label.
  required final String label,

  /// Called when the button is tapped.
  required final VoidCallback onPressed,

  /// Optional icon placed before the [label].
  final IconData? icon,
});

/// An inline alert / notification card — a faithful port of the Figma
/// `pregoInlineAlertsNotifications` component.
///
/// Includes 16px outer spacing around the rounded card, including when hosted
/// in a navigation banner slot.
///
/// Anatomy (left → right, top → bottom):
/// - a leading status icon (or a spinner for
///   [PregoInlineAlertsNotificationsType.loading]),
/// - a medium-weight [title],
/// - an optional [secondaryAction] (a tertiary, label-only button),
/// - an optional [primaryAction] (a solid, accent-coloured button),
/// - an optional close button (shown when [onClose] is non-null),
/// - optional [supportingText] and/or [additionalContent] below the title.
/// Usage:
/// ```dart
/// PregoInlineAlertsNotifications(
///   type: PregoInlineAlertsNotificationsType.warning,
///   title: 'Bridge offline',
///   supportingText: 'Reconnect to keep your session in sync.',
///   primaryAction: PregoInlineAlertsNotificationsAction(
///     label: 'Reconnect',
///     icon: TablerRegular.rotate_clockwise,
///     onPressed: _reconnect,
///   ),
///   secondaryAction: PregoInlineAlertsNotificationsAction(
///     label: 'Dismiss',
///     onPressed: _dismiss,
///   ),
///   onClose: _dismiss,
/// )
/// ```
class const PregoInlineAlertsNotifications({
  super.key,

  /// Medium-weight headline shown on the first row. Long titles ellipsize on a
  /// single line so the actions stay aligned to the trailing edge.
  required final String title,

  /// Selects the leading icon, accent gradient, and primary-action fill.
  final PregoInlineAlertsNotificationsType type = PregoInlineAlertsNotificationsType.info,

  /// Optional supporting text shown below the title. When `null`, no supporting
  /// text row is rendered.
  final String? supportingText,

  /// Overrides the leading icon. When `null`, the [type]'s default icon is
  /// used. Ignored for [PregoInlineAlertsNotificationsType.loading], which
  /// always shows a spinner.
  final IconData? icon,

  /// Optional primary (solid, accent-coloured) action button. When `null`, no
  /// primary button is rendered.
  final PregoInlineAlertsNotificationsAction? primaryAction,

  /// Optional secondary (tertiary, label-only) action button, placed before
  /// the [primaryAction]. When `null`, no secondary button is rendered.
  final PregoInlineAlertsNotificationsAction? secondaryAction,

  /// Called when the close button is tapped. When `null`, the close button is
  /// not rendered.
  final VoidCallback? onClose,

  /// Optional custom widget rendered in the content column, below the
  /// [supportingText]. Use for richer content (links, inline controls, etc.).
  final Widget? additionalContent,
}) extends StatelessWidget {
  static const double _leadingGap = PregoSpacing.sm;

  // Leading icon glyph size (Figma: 22px). The loading spinner is 20px.
  static const double _iconSize = 22.0;
  static const double _spinnerSize = 20.0;

  bool get _isLoading => type == PregoInlineAlertsNotificationsType.loading;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.xl),
      // Material supplies text defaults outside a Scaffold and clips both the
      // accent and action ink to the card, with its border in the foreground.
      child: Material(
        color: colors.bgSurface5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
          side: BorderSide(color: colors.borderPrimary),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: IgnorePointer(child: _accentGradient(colors))),
            Padding(
              padding: const EdgeInsets.all(PregoSpacing.xl),
              child: _buildBody(prego, brightness: Theme.of(context).brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PregoDesignSystem prego, {required Brightness brightness}) {
    final colors = prego.colors;
    final hasBelow = supportingText != null || additionalContent != null;

    // First row: leading icon centred against the title row (which is as tall
    // as its tallest action button), then the title + trailing actions.
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLeading(colors, brightness: brightness),
        const SizedBox(width: _leadingGap),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
          ),
        ),
        if (_buildActions() case final actions?) ...[
          const SizedBox(width: PregoSpacing.md),
          actions,
        ],
      ],
    );

    if (!hasBelow) return titleRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleRow,
        // Content below the title is indented to align under the title text
        // (past the leading icon), matching Figma's icon + text-column layout.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _iconSize + _leadingGap,
            top: PregoSpacing.lg,
          ),
          child: _buildBelow(prego),
        ),
      ],
    );
  }

  Widget _buildBelow(PregoDesignSystem prego) {
    final colors = prego.colors;
    final supporting = supportingText;
    final extra = additionalContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (supporting != null)
          Text(
            supporting,
            style: prego.textTheme.textSm.medium.copyWith(color: colors.textSecondary),
          ),
        if (supporting != null && extra != null) const SizedBox(height: PregoSpacing.lg),
        ?extra,
      ],
    );
  }

  Widget _buildLeading(PregoColors colors, {required Brightness brightness}) {
    if (_isLoading) {
      return SizedBox.square(
        dimension: _spinnerSize,
        child: PregoActivityIndicator.onSurface(brightness: brightness, color: null),
      );
    }
    return Icon(icon ?? _defaultIcon, size: _iconSize, color: _iconColor(colors));
  }

  /// Builds the trailing action cluster (secondary + primary + close), or
  /// `null` when none of the three are present.
  Widget? _buildActions() {
    final primary = primaryAction;
    final secondary = secondaryAction;
    final close = onClose;
    if (primary == null && secondary == null && close == null) return null;

    final (hierarchy, tone) = _primaryButtonStyle;

    final children = <Widget>[
      if (secondary != null)
        PregoButtonsSolid(
          label: secondary.label,
          leadingIcon: secondary.icon,
          hierarchy: PregoButtonsSolidHierarchy.tertiary,
          size: PregoButtonsSolidSize.sm,
          onPressed: secondary.onPressed,
        ),
      if (primary != null)
        PregoButtonsSolid(
          label: primary.label,
          leadingIcon: primary.icon,
          hierarchy: hierarchy,
          size: PregoButtonsSolidSize.sm,
          type: tone,
          onPressed: primary.onPressed,
        ),
      if (close != null)
        PregoButtonsSolid.iconOnly(
          leadingIcon: TablerRegular.x,
          hierarchy: PregoButtonsSolidHierarchy.tertiary,
          size: PregoButtonsSolidSize.sm,
          onPressed: close,
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: PregoSpacing.lg),
          children[i],
        ],
      ],
    );
  }

  Widget _accentGradient(PregoColors colors) {
    final rim = switch (type) {
      PregoInlineAlertsNotificationsType.info || PregoInlineAlertsNotificationsType.loading => colors.bgSurface5,
      PregoInlineAlertsNotificationsType.success => colors.bgSuccessSecondary,
      PregoInlineAlertsNotificationsType.warning => colors.bgWarningSecondary,
      PregoInlineAlertsNotificationsType.error => colors.bgErrorSecondary,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1,
          transform: const _WideEllipseGradientTransform(),
          // Figma holds the surface colour through 60% of the ellipse, then
          // fades to the status tint, with 20% opacity over the whole gradient.
          stops: const [0.6, 1],
          colors: [colors.bgSurface5.withValues(alpha: 0.20), rim.withValues(alpha: 0.20)],
        ),
      ),
    );
  }

  /// Hierarchy + tone for the primary action button, per [type].
  (PregoButtonsSolidHierarchy, PregoButtonsSolidType) get _primaryButtonStyle => switch (type) {
    PregoInlineAlertsNotificationsType.info => (
      PregoButtonsSolidHierarchy.primary,
      PregoButtonsSolidType.regular,
    ),
    PregoInlineAlertsNotificationsType.success => (
      PregoButtonsSolidHierarchy.primary,
      PregoButtonsSolidType.success,
    ),
    PregoInlineAlertsNotificationsType.warning => (
      PregoButtonsSolidHierarchy.primary,
      PregoButtonsSolidType.warning,
    ),
    PregoInlineAlertsNotificationsType.error => (
      PregoButtonsSolidHierarchy.primary,
      PregoButtonsSolidType.destructive,
    ),
    // Loading keeps the neutral primary-alt action treatment.
    PregoInlineAlertsNotificationsType.loading => (
      PregoButtonsSolidHierarchy.primaryAlt,
      PregoButtonsSolidType.regular,
    ),
  };

  IconData get _defaultIcon => switch (type) {
    PregoInlineAlertsNotificationsType.info ||
    // Unused for loading (a spinner is shown), but the switch is exhaustive.
    PregoInlineAlertsNotificationsType.loading => TablerRegular.info_circle,
    PregoInlineAlertsNotificationsType.success => TablerRegular.circle_check,
    PregoInlineAlertsNotificationsType.warning => TablerRegular.alert_triangle,
    PregoInlineAlertsNotificationsType.error => TablerRegular.alert_circle,
  };

  Color _iconColor(PregoColors colors) => switch (type) {
    PregoInlineAlertsNotificationsType.info || PregoInlineAlertsNotificationsType.loading => colors.textPrimary,
    PregoInlineAlertsNotificationsType.success => colors.fgSuccessSecondary,
    PregoInlineAlertsNotificationsType.warning => colors.fgWarningSecondary,
    PregoInlineAlertsNotificationsType.error => colors.fgErrorSecondary,
  };
}

/// Maps the radial to Figma's ellipse: vertical radius is the card height;
/// horizontal radius is 1.3075 times its width, centred on the top edge.
class const _WideEllipseGradientTransform() extends GradientTransform {
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final scaleX = bounds.width * 1.3075 / bounds.shortestSide;
    final scaleY = bounds.height / bounds.shortestSide;
    final centerX = bounds.center.dx;
    return Matrix4(
      scaleX,
      0,
      0,
      0, // column 0
      0,
      scaleY,
      0,
      0, // column 1
      0,
      0,
      1,
      0, // column 2
      centerX * (1 - scaleX),
      bounds.top * (1 - scaleY),
      0,
      1, // column 3 (translation)
    );
  }
}
