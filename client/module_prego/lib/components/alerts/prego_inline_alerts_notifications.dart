import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../motion/prego_reduced_motion.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";
import "../loaders/prego_activity_indicator.dart";
import "../loaders/prego_ai_loader.dart";

/// Visual type for [PregoInlineAlertsNotifications] — the Figma component's
/// `Type` property.
///
/// Each value selects the leading status icon, the warm accent gradient, and
/// the fill of the primary action button.
enum PregoInlineAlertsNotificationsType() {
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

  /// In-progress — the coordinated Figma deep-scan presentation: rotating AI
  /// sparkle, masked skeleton rows, and a travelling scan beam.
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
/// `pregoInlineAletsNotifications` component (sic).
///
/// Anatomy (left → right, top → bottom):
/// - a leading status icon (or the coordinated sparkle for
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
class const PregoInlineAlertsNotifications({
    super.key,
    /// Bold headline text shown on the first row. Long titles ellipsize on a
  /// single line so the actions stay aligned to the trailing edge.
  required final String title,
    /// Selects the leading icon, accent gradient, and primary-action fill.
  final PregoInlineAlertsNotificationsType type = PregoInlineAlertsNotificationsType.info,
    /// Optional supporting text shown below the title. When `null`, no supporting
  /// text row is rendered.
  final String? supportingText,
    /// Overrides the leading icon. When `null`, the [type]'s default icon is
  /// used. Ignored for [PregoInlineAlertsNotificationsType.loading], which
  /// always shows the designed rotating sparkle.
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
    /// Accessible label for the icon-only close button. The loading treatment
  /// falls back to the platform-localized close label when this is `null`.
  final String? closeSemanticLabel,
    /// Optional custom widget rendered in the content column, below the
  /// [supportingText]. Use for richer content (links, inline controls, etc.).
  final Widget? additionalContent,
  }) extends StatelessWidget {
  // Gap between the leading icon and the content column. Figma uses 10px —
  // between spacing-md (8) and spacing-lg (12) — so it has no named token.
  static const double _leadingGap = 10.0;

  // Leading icon glyph size (Figma: 22px). The loading spinner is 20px.
  static const double _iconSize = 22.0;
  static const double _spinnerSize = 20.0;

  bool get _isLoading => type == PregoInlineAlertsNotificationsType.loading;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _PregoLoadingInlineAlert(
        title: title,
        supportingText: supportingText,
        onClose: onClose,
        closeSemanticLabel: closeSemanticLabel,
      );
    }
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
        child: PregoActivityIndicator(color: colors.buttonPrimaryIcon),
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

/// Figma's coordinated loading alert, kept private so the public component's
/// closed [PregoInlineAlertsNotificationsType] API remains the only entrypoint.
class const _PregoLoadingInlineAlert({
  required final String title,
  required final String? supportingText,
  required final VoidCallback? onClose,
  required final String? closeSemanticLabel,
}) extends StatefulWidget {
  @override
  State<_PregoLoadingInlineAlert> createState() => _PregoLoadingInlineAlertState();
}

class _PregoLoadingInlineAlertState() extends State<_PregoLoadingInlineAlert>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  /// Figma coordinates both moving pieces on one ten-second looping timeline.
  static const Duration _period = Duration(seconds: 10);

  late final AnimationController _timeline = AnimationController(vsync: this, duration: _period);
  // Figma's outlined sparkle rotates linearly through five full turns across
  // the entire ten-second timeline (one turn every two seconds).
  late final Animation<double> _loaderTurns = Tween(begin: 0.0, end: 5.0).animate(_timeline);
  late final Animation<double> _beamX = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: -18.0, end: 128.181).chain(
        CurveTween(curve: const Cubic(0.45, 0, 0.55, 1)),
      ),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(128.181), weight: 75),
  ]).animate(_timeline);

  @override
  bool get motionEnabled => true;

  @override
  void startMotion() {
    if (!_timeline.isAnimating) _timeline.repeat();
  }

  @override
  void stopMotion() {
    if (_timeline.isAnimating) _timeline.stop();
    // Reduced motion uses the intentional first frame, not an arbitrary point
    // at which the platform preference happened to change.
    _timeline.value = 0;
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final close = widget.onClose;
    final clipShape = _deepScanCardShape(context);
    final outlineShape = _deepScanCardShape(
      context,
      side: BorderSide(color: colors.borderPrimary),
    );
    // The updated Figma graphic uses the theme-aware brand-gradient endpoint:
    // white in dark mode and Blue/400 (#4D94FF) in light mode.
    final beamColor = colors.brandGradientTop;
    // The light beam needs less visual weight against a white card than the
    // original dark Figma beam: 0.48 is a 20% reduction from its 0.60 alpha.
    final beamOpacity = colors.brightness == Brightness.dark ? 0.6 : 0.48;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(PregoSpacing.xl),
        child: SizedBox(
          height: 69,
          child: Container(
            key: const ValueKey("prego-deep-scan-card"),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: colors.bgSurface5,
              shape: clipShape,
            ),
            foregroundDecoration: ShapeDecoration(shape: outlineShape),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PositionedDirectional(
                  // The 104px mask starts 14px above the 69px viewport in
                  // Figma; the first row itself starts at y=2 inside it.
                  top: -14,
                  end: 21,
                  width: _LoadingScanPanel.width,
                  height: _LoadingScanPanel.height,
                  child: RepaintBoundary(
                    key: const ValueKey("prego-deep-scan-panel"),
                    child: _LoadingScanPanel(
                      beamX: _beamX,
                      skeletonFillColor: colors.bgSurface6,
                      skeletonShadowColor: colors.shadowXs,
                      skeletonInnerBorderColor: colors.skeuomorphicInnerBorder,
                      skeletonBottomShadowColor: colors.skeuomorphicShadow,
                      beamColor: beamColor,
                      beamOpacity: beamOpacity,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
                  child: Row(
                    children: [
                      RotationTransition(
                        key: const ValueKey("prego-deep-scan-loader"),
                        turns: _loaderTurns,
                        child: PregoAiLoader(
                          size: 20,
                          animate: false,
                          fillMode: .outline,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: PregoSpacing.sm),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(height: PregoSpacing.xxs),
                            Text(
                              widget.supportingText ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (close != null) ...[
                        const SizedBox(width: PregoSpacing.lg),
                        _LoadingCloseButton(
                          semanticLabel: widget.closeSemanticLabel,
                          onPressed: close,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The shared Deep Scan silhouette: a 24px radius everywhere, with Flutter's
/// native Apple-style continuous curve on iOS. [RoundedSuperellipseBorder] is
/// the native approximation of Figma's 60% corner smoothing; Android keeps the
/// same radius with Material's circular corner geometry.
ShapeBorder _deepScanCardShape(
  BuildContext context, {
  BorderSide side = BorderSide.none,
}) {
  const radius = BorderRadius.all(Radius.circular(PregoRadius.x4l));
  return Theme.of(context).platform == TargetPlatform.iOS
      ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
      : RoundedRectangleBorder(borderRadius: radius, side: side);
}

/// The masked skeleton rows and travelling beam on the alert's trailing side.
class const _LoadingScanPanel({
  required final Animation<double> beamX,
  required final Color skeletonFillColor,
  required final Color skeletonShadowColor,
  required final Color skeletonInnerBorderColor,
  required final Color skeletonBottomShadowColor,
  required final Color beamColor,
  required final double beamOpacity,
}) extends StatelessWidget {
  static const double width = 142;
  static const double height = 104;
  static const double _beamWidth = 12.6;
  static const double _beamHeight = 127.6;
  static const double _beamOriginX = 18;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => ui.Gradient.linear(
          Offset(7, bounds.center.dy),
          Offset(99, bounds.center.dy),
          const [Colors.transparent, Colors.white, Colors.transparent],
          const [0, 0.25, 1],
        ),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              painter: _LoadingSkeletonPainter(
                fillColor: skeletonFillColor,
                shadowColor: skeletonShadowColor,
                innerBorderColor: skeletonInnerBorderColor,
                bottomShadowColor: skeletonBottomShadowColor,
              ),
            ),
            Positioned(
              left: _beamOriginX,
              top: (height - _beamHeight) / 2,
              width: _beamWidth,
              height: _beamHeight,
              child: AnimatedBuilder(
                animation: beamX,
                child: CustomPaint(
                  painter: _LoadingBeamPainter(
                    color: beamColor,
                    opacity: beamOpacity,
                  ),
                ),
                builder: (context, child) => Transform.translate(
                  key: const ValueKey("prego-deep-scan-beam"),
                  offset: Offset(beamX.value, 0),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeletonPainter({
  required final Color fillColor,
  required final Color shadowColor,
  required final Color innerBorderColor,
  required final Color bottomShadowColor,
}) extends CustomPainter {
  static const _bars = <(Offset, double)>[
    (Offset(29, 2), 0.3),
    (Offset(45, 27), 0.6),
    (Offset(45, 52), 0.6),
    (Offset(29, 77), 0.3),
  ];

  static const Size _barSize = Size(122, 21);
  static const Radius _barRadius = Radius.circular(5.918);
  static const double _effectScale = 0.74;
  static const double _bottomShadowHeight = 1.479;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (origin, opacity) in _bars) {
      final rect = origin & _barSize;
      final rrect = RRect.fromRectAndRadius(rect, _barRadius);

      // Figma applies the row opacity after compositing its fill and effects.
      // A layer preserves that group-opacity behavior instead of multiplying
      // each overlapping stroke independently.
      canvas.saveLayer(
        rect.inflate(4),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );

      final shadow = BoxShadow(
        color: shadowColor,
        offset: const Offset(0, _effectScale),
        blurRadius: _bottomShadowHeight,
      );
      canvas.drawRRect(rrect.shift(shadow.offset), shadow.toPaint());
      canvas.drawRRect(rrect, Paint()..color = fillColor);

      // Figma: inset 0 -1.479px 0, clipped to the rounded row.
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.bottom - _bottomShadowHeight,
          rect.width,
          _bottomShadowHeight,
        ),
        Paint()..color = bottomShadowColor,
      );
      canvas.restore();

      // Figma: inset 0 0 0 0.74px, painted above the bottom inset shadow.
      canvas.drawRRect(
        rrect.deflate(_effectScale / 2),
        Paint()
          ..color = innerBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _effectScale,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LoadingSkeletonPainter oldDelegate) {
    return fillColor != oldDelegate.fillColor ||
        shadowColor != oldDelegate.shadowColor ||
        innerBorderColor != oldDelegate.innerBorderColor ||
        bottomShadowColor != oldDelegate.bottomShadowColor;
  }
}

class const _LoadingBeamPainter({required final Color color, required final double opacity})
    extends CustomPainter {
  static const double _strokeWidth = 6;
  static const double _blurSigma = 1.65;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width / 2, 3.3);
    final end = Offset(size.width / 2, size.height - 3.3);
    final paintedColor = color.withValues(alpha: color.a * opacity);

    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = paintedColor
        ..strokeWidth = _strokeWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blurSigma),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = paintedColor
        ..strokeWidth = _strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_LoadingBeamPainter oldDelegate) {
    return color != oldDelegate.color || opacity != oldDelegate.opacity;
  }
}

class const _LoadingCloseButton({
  required final String? semanticLabel,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final radius = BorderRadius.circular(PregoRadius.full);
    final label = semanticLabel ?? MaterialLocalizations.of(context).closeButtonTooltip;

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 36,
          child: PregoTappable(
            onTap: onPressed,
            borderRadius: radius,
            overlayInset: 1,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return colors.bgGrayPressed;
              if (states.contains(WidgetState.hovered)) return colors.bgGrayHover;
              return null;
            }),
            containerBuilder: (child) => DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bgSurface4,
                border: Border.all(color: colors.borderSecondary),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(color: colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    child,
                    PregoSkeuomorphicOverlay(
                      innerBorderColor: colors.skeuomorphicInnerBorder,
                      bottomShadowColor: colors.skeuomorphicShadow,
                    ),
                  ],
                ),
              ),
            ),
            child: Center(
              child: Icon(TablerRegular.x, size: 20, color: colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
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
class const _InvertedSurfaceTheme({required final Widget child}) extends StatelessWidget {
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
class const _WideEllipseGradientTransform(
  /// How many times wider than tall each iso-colour ring is drawn.
  final double scaleX) extends GradientTransform {
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
