import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";

/// Visual type for [PregoInlineAlertsNotifications] — the Figma component's
/// `Type` property.
///
/// Each value selects the leading status icon, the warm accent gradient, and
/// the fill of the primary action button.
enum PregoInlineAlertsNotificationsType {
  /// Neutral / informational — `circle-info` icon, brand-blue action button,
  /// neutral (dark→white) accent glow.
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
  /// renders in the inverted ("primary alt") style, and the accent glow is
  /// neutral (as for [info]).
  loading,
}

/// Configuration for one of [PregoInlineAlertsNotifications]'s action buttons.
///
/// Used for both the primary ("Learn more") and secondary buttons. Pass `null`
/// for the corresponding [PregoInlineAlertsNotifications] field to omit a
/// button.
class PregoInlineAlertsNotificationsAction {
  const PregoInlineAlertsNotificationsAction({
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

/// An inline alert / notification card — a faithful port of the Figma
/// `pregoInlineAletsNotifications` component (sic).
///
/// Anatomy (left → right, top → bottom):
/// - a leading status icon (or a spinner for
///   [PregoInlineAlertsNotificationsType.loading]),
/// - a bold [title],
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
class PregoInlineAlertsNotifications extends StatelessWidget {
  const PregoInlineAlertsNotifications({
    super.key,
    required this.title,
    this.type = PregoInlineAlertsNotificationsType.info,
    this.supportingText,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.onClose,
    this.additionalContent,
  });

  /// Bold headline text shown on the first row. Long titles ellipsize on a
  /// single line so the actions stay aligned to the trailing edge.
  final String title;

  /// Selects the leading icon, accent gradient, and primary-action fill.
  final PregoInlineAlertsNotificationsType type;

  /// Optional supporting text shown below the title. When `null`, no supporting
  /// text row is rendered.
  final String? supportingText;

  /// Overrides the leading icon. When `null`, the [type]'s default icon is
  /// used. Ignored for [PregoInlineAlertsNotificationsType.loading], which
  /// always shows a spinner.
  final IconData? icon;

  /// Optional primary (solid, accent-coloured) action button. When `null`, no
  /// primary button is rendered.
  final PregoInlineAlertsNotificationsAction? primaryAction;

  /// Optional secondary (tertiary, label-only) action button, placed before
  /// the [primaryAction]. When `null`, no secondary button is rendered.
  final PregoInlineAlertsNotificationsAction? secondaryAction;

  /// Called when the close button is tapped. When `null`, the close button is
  /// not rendered.
  final VoidCallback? onClose;

  /// Optional custom widget rendered in the content column, below the
  /// [supportingText]. Use for richer content (links, inline controls, etc.).
  final Widget? additionalContent;

  // Gap between the leading icon and the content column. Figma uses 10px —
  // between spacing-md (8) and spacing-lg (12) — so it has no named token.
  static const double _leadingGap = 10.0;

  // Leading icon glyph size (Figma: 22px). The loading spinner is 20px.
  static const double _iconSize = 22.0;
  static const double _spinnerSize = 20.0;

  bool get _isLoading => type == PregoInlineAlertsNotificationsType.loading;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: _buildCard);
  }

  Widget _buildCard(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    // Transparent [Material] so the title/supporting [Text] inherit a proper
    // default text style even when the banner is placed outside a
    // [Scaffold]/[Material] — e.g. directly in an overlay [Stack]. Without it,
    // the text falls back to Flutter's debug style (yellow double underline).
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: colors.fgPrimary,
            ),
          ),
          // Warm accent glow: a wide, shallow ellipse emanating from the
          // top-centre, fading out to the type's accent colour at the rim.
          Positioned.fill(
            child: IgnorePointer(child: _accentGradient(colors)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              PregoSpacing.xl, // 16
              PregoSpacing.lg, // 12
              PregoSpacing.lg, // 12
              PregoSpacing.lg, // 12
            ),
            child: _buildBody(prego),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PregoDesignSystem prego) {
    final colors = prego.colors;
    final hasBelow = supportingText != null || additionalContent != null;

    // First row: leading icon centred against the title row (which is as tall
    // as its tallest action button), then the title + trailing actions.
    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildLeading(colors),
        const SizedBox(width: _leadingGap),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.bold.copyWith(color: colors.alphaWhite100),
          ),
        ),
        if (_buildActions(colors) case final actions?) ...[
          const SizedBox(width: PregoSpacing.md),
          // The card surface is `fgPrimary` — the inverse of the page
          // background — so action buttons that resolve their foreground from
          // semantic page tokens (a tertiary [PregoButtonsSolid]'s
          // `textTertiary` label, the loading `primaryAlt` fill) would be
          // mis-toned against it. Render the cluster under the opposite-
          // brightness palette so those tokens land on the right side of the
          // surface in both themes.
          _InvertedSurfaceTheme(child: actions),
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
            style: prego.textTheme.textSm.medium.copyWith(color: colors.alphaWhite70),
          ),
        if (supporting != null && extra != null) const SizedBox(height: PregoSpacing.lg),
        ?extra,
      ],
    );
  }

  Widget _buildLeading(PregoColors colors) {
    if (_isLoading) {
      return SizedBox.square(
        dimension: _spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colors.buttonPrimaryIcon),
        ),
      );
    }
    return Icon(icon ?? _defaultIcon, size: _iconSize, color: _iconColor(colors));
  }

  /// Builds the trailing action cluster (secondary + primary + close), or
  /// `null` when none of the three are present.
  Widget? _buildActions(PregoColors colors) {
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
    // (centre, rim) colours with Figma's master opacity already baked in.
    // info/loading: gray-950 @ ~12% fading to white @ ~18% (a faint top-centre
    // vignette). success/warning/error: ~3% white fading to the accent @ 30%.
    final (Color center, Color rim) = switch (type) {
      PregoInlineAlertsNotificationsType.info || PregoInlineAlertsNotificationsType.loading => (
        const Color(0x1F0C0E12),
        const Color(0x2EFFFFFF),
      ),
      PregoInlineAlertsNotificationsType.success => (
        const Color(0x08FFFFFF),
        colors.fgSuccessSecondary.withValues(alpha: 0.30),
      ),
      PregoInlineAlertsNotificationsType.warning => (
        const Color(0x08FFFFFF),
        colors.fgWarningPrimary.withValues(alpha: 0.30),
      ),
      PregoInlineAlertsNotificationsType.error => (
        const Color(0x08FFFFFF),
        colors.fgErrorPrimary.withValues(alpha: 0.30),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          // Just below the top edge — matches Figma's gradient origin.
          center: const Alignment(0, -0.885),
          // Vertical reach lands the rim colour on the bottom edge.
          radius: 0.94,
          // Flutter has no native elliptical radial gradient, so the circle is
          // stretched horizontally into a wide, shallow glow (~6.7x).
          transform: const _WideEllipseGradientTransform(6.7),
          colors: [center, rim],
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
    // Loading: inverted white fill with dark text (Figma: fg-primary fill).
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
    // Info icon is near-black (Figma: alpha-white-100). Loading is unused.
    PregoInlineAlertsNotificationsType.info || PregoInlineAlertsNotificationsType.loading => colors.alphaWhite100,
    PregoInlineAlertsNotificationsType.success => colors.fgSuccessSecondary,
    PregoInlineAlertsNotificationsType.warning => colors.fgWarningSecondary,
    PregoInlineAlertsNotificationsType.error => colors.fgErrorSecondary,
  };
}

/// Re-themes [child] with the opposite-brightness [PregoDesignSystem].
///
/// The alert card paints its surface with `fgPrimary`, which is the inverse of
/// the page background in each theme (a dark surface in light mode, a light
/// surface in dark mode). Controls that resolve colours from semantic page
/// tokens — e.g. a tertiary [PregoButtonsSolid] using `textTertiary`, or the
/// loading-type `primaryAlt` fill — are tuned for the page background, so they
/// sit on the wrong side of this inverted surface. Wrapping them in the
/// opposite-brightness palette puts every token back on the correct side.
class _InvertedSurfaceTheme extends StatelessWidget {
  const _InvertedSurfaceTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inverted = theme.brightness == Brightness.light
        ? PregoDesignSystem.dark
        : PregoDesignSystem.light;
    // Append after the existing extensions so the inverted PregoDesignSystem
    // wins by type; all other theme extensions are preserved.
    return Theme(
      data: theme.copyWith(extensions: [...theme.extensions.values, inverted]),
      child: child,
    );
  }
}

/// Stretches a [RadialGradient] horizontally into a wide, shallow ellipse.
///
/// Flutter's [RadialGradient] only draws circles; scaling the shader's local
/// matrix about the gradient centre (the card's horizontal midpoint) turns the
/// circular iso-colour rings into ellipses [scaleX] times wider than they are
/// tall. The warm overlay then fans out almost horizontally, as if its centre
/// sat far above the card — matching the Figma radial.
class _WideEllipseGradientTransform extends GradientTransform {
  const _WideEllipseGradientTransform(this.scaleX);

  /// How many times wider than tall each iso-colour ring is drawn.
  final double scaleX;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Scale x by [scaleX] about the gradient centre (the card's mid-x). The
    // translation term keeps that centre fixed: x' = scaleX·x + cx·(1 - scaleX).
    final centerX = bounds.center.dx;
    return Matrix4(
      scaleX,
      0,
      0,
      0, // column 0
      0,
      1,
      0,
      0, // column 1
      0,
      0,
      1,
      0, // column 2
      centerX * (1 - scaleX),
      0,
      0,
      1, // column 3 (translation)
    );
  }
}
