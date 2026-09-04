import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart" show PregoSkeuomorphicOverlay;
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../l10n/app_localizations.dart";

/// How long the row takes to grow in or fold away.
const Duration _revealDuration = Duration(milliseconds: 260);
const Curve _revealEaseOut = Cubic(0.23, 1, 0.32, 1);
// A compact optical entrance: close enough to full size that text stays stable,
// with just enough blur to connect the card to the pull without looking glassy.
const double _entranceScaleFrom = 0.97;
const double _entranceBlurSigma = 2;

/// The catalog scan reported as one quiet row above a list.
///
/// Live scans use the coordinated loading card designed for this flow;
/// terminal outcomes keep their severity-tinted report cards.
///
/// Its height never changes while the scan is live. The supporting line always
/// occupies a row, so a scan that starts before it can name a harness does not
/// shove the list down again when the first progress event lands.
class const CatalogScanRow({
  super.key,

  /// The scan to report, read from the hosting list's own state so the row
  /// re-renders with the list rather than subscribing separately.
  required final CatalogRescanState _scan,

  /// Stops a scan in flight. Offered while the scan is live, because the pull
  /// gesture commits mid-drag and has no release to cancel on.
  required final VoidCallback _onCancel,

  /// Clears a finished scan the user has read.
  required final VoidCallback _onDismiss,
}) extends StatefulWidget {
  /// The pull-to-refresh second stage that starts a scan, carrying the caption
  /// that says what crossing the deeper threshold will do.
  ///
  /// Lives beside the row so the gesture that starts a scan and the row that
  /// reports it stay worded together, and every list gets the same invitation.
  static PregoDeepRefresh deepRefresh({required BuildContext context, required VoidCallback onStart}) {
    return PregoDeepRefresh(onDeepRefresh: onStart, pullCaption: context.loc.catalogScanPullCaption);
  }

  @override
  State<CatalogScanRow> createState() => _CatalogScanRowState();
}

class _CatalogScanRowState() extends State<CatalogScanRow> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealDuration,
    // A scan already running when this mounts is not news: the list is being
    // revisited mid-run, so the row is simply there rather than arriving.
    value: _hasContent ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _reveal,
    curve: _revealEaseOut,
    // The flipped strong ease-out makes the visible exit snap first and settle
    // softly while the controller itself runs backwards.
    reverseCurve: const FlippedCurve(_revealEaseOut),
  );
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _revealDuration,
    value: _hasContent ? 1 : 0,
  );
  late final CurvedAnimation _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: _revealEaseOut,
  );

  /// The last content worth showing, kept while the row folds away.
  ///
  /// Without it the card would vanish on the frame the scan cleared and leave
  /// an empty box collapsing behind it.
  _RowContent? _shown;

  /// Whether the current scan has anything to report. Decided from the scan
  /// alone, so the animation can be driven from lifecycle callbacks rather than
  /// from [build], where starting a controller races its own frame.
  bool get _hasContent => widget._scan is! CatalogRescanIdle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drops the retained card once it has finished folding away. Without this
    // its labels and its live action button stay mounted at zero height, where
    // a keyboard or screen reader can still reach an invisible control.
    _reveal.addStatusListener(_onRevealStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReducedMotionPreference();
  }

  @override
  void didUpdateWidget(CatalogScanRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reducedMotion = _syncReducedMotionPreference();
    final hadContent = oldWidget._scan is! CatalogRescanIdle;
    if (_hasContent) {
      _reveal.forward();
      if (!hadContent) {
        if (reducedMotion) {
          _entrance.value = 1;
        } else {
          _entrance.forward(from: 0);
        }
      }
    } else {
      _reveal.reverse();
    }
  }

  /// Keeps the finite entrance in step with both platform accessibility APIs.
  ///
  /// Android's "Remove animations" reaches [MediaQuery], while iOS Reduce
  /// Motion is a separate dispatcher feature. The shared PREGO helper reads
  /// both; the observer below also settles an entrance if the preference is
  /// enabled during its short run.
  bool _syncReducedMotionPreference() {
    final reducedMotion = prefersReducedMotion(context);
    _reveal.duration = reducedMotion ? Duration.zero : _revealDuration;
    if (reducedMotion) {
      if (_reveal.isAnimating) _reveal.value = _hasContent ? 1 : 0;
      if (_entrance.isAnimating) _entrance.value = 1;
    }
    return reducedMotion;
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    if (!mounted) return;
    _syncReducedMotionPreference();
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _shown == null) return;
    setState(() => _shown = null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reveal.removeStatusListener(_onRevealStatus);
    _entranceCurve.dispose();
    _entrance.dispose();
    _curve.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(loc: context.loc, scan: widget._scan);
    if (content != null) _shown = content;
    final shown = _shown;
    if (shown == null) return const SizedBox(width: double.infinity);

    return SizeTransition(
      sizeFactor: _curve,
      // Grow downward from the top edge so the list below slides rather than
      // the row expanding around its own centre.
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: _curve,
        // Announced when it appears without moving focus, the same treatment
        // the connection banner uses: a scan started by a pull finishes with
        // no other signal that it is done. Every state announces except the
        // running one, whose session count changes with each enumerated
        // session and would otherwise interrupt a screen reader hundreds of
        // times during one scan.
        child: AnimatedBuilder(
          animation: _entrance,
          builder: (context, child) {
            final progress = _entranceCurve.value;
            final scale = _entranceScaleFrom + (1 - _entranceScaleFrom) * progress;
            final blurSigma = _entranceBlurSigma * (1 - progress);
            final filteredChild = blurSigma <= 0
                ? child
                : ImageFiltered(
                    key: const ValueKey("catalog-scan-row-entrance-blur"),
                    imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                    child: child,
                  );
            return Transform.scale(
              key: const ValueKey("catalog-scan-row-entrance"),
              alignment: Alignment.topCenter,
              scale: scale,
              child: filteredChild,
            );
          },
          // AnimatedBuilder retains this subtree while only the composited
          // entrance transform and its short-lived image filter change.
          child: Semantics(
            container: true,
            // Keep the icon-only cancel action as a separately focusable node;
            // otherwise this live-region container merges its localized label
            // into the changing status announcement.
            explicitChildNodes: true,
            liveRegion: widget._scan is! CatalogRescanRunning,
            child: shown.tone == _ScanTone.working
                ? _ScanLoadingCard(
                    title: shown.title,
                    supportingText: shown.detail,
                    cancelLabel: shown.actionLabel,
                    onCancel: shown.onAction,
                  )
                : Padding(
                    padding: const EdgeInsetsDirectional.all(PregoSpacing.xl),
                    child: _ScanCard(content: shown),
                  ),
          ),
        ),
      ),
    );
  }

  /// The one place the scan state decides how the row reads.
  ///
  /// `null` is the idle row, which folds away to nothing.
  _RowContent? _contentFor({required AppLocalizations loc, required CatalogRescanState scan}) => switch (scan) {
    CatalogRescanIdle() => null,
    // The spinner is the progress report: a scan has no total to count towards,
    // so there is nothing to fill a bar with. The detail line holds its place
    // until the first harness reports.
    CatalogRescanStarting() => _RowContent(
      tone: _ScanTone.working,
      title: loc.catalogScanRunningTitle,
      detail: loc.catalogScanStartingDetail,
      actionLabel: loc.catalogScanCancel,
      onAction: widget._onCancel,
    ),
    CatalogRescanRunning(:final activePluginName, :final sessionsSeen) => _RowContent(
      tone: _ScanTone.working,
      title: loc.catalogScanRunningTitle,
      detail: loc.catalogScanRunningDetail(activePluginName, sessionsSeen),
      actionLabel: loc.catalogScanCancel,
      onAction: widget._onCancel,
    ),
    CatalogRescanSucceeded(:final counts) => _RowContent(
      tone: _ScanTone.done,
      icon: TablerRegular.circle_check,
      title: loc.catalogScanCompleteTitle,
      detail: catalogScanCountsLine(loc: loc, counts: counts),
      actionLabel: loc.catalogScanDismiss,
      onAction: widget._onDismiss,
    ),
    CatalogRescanPartlyFailed(:final succeededCount, :final failedCount) => _RowContent(
      tone: _ScanTone.attention,
      icon: TablerRegular.alert_triangle,
      title: loc.catalogScanPartlyFailedTitle,
      detail: loc.catalogScanPartlyFailedDetail(failedCount, succeededCount + failedCount),
      actionLabel: loc.catalogScanDismiss,
      onAction: widget._onDismiss,
    ),
    // The bridge's own error text never reaches the client, so the row names
    // the log that has it rather than guessing at a cause.
    CatalogRescanFailed() => _RowContent(
      tone: _ScanTone.problem,
      icon: TablerRegular.alert_circle,
      title: loc.catalogScanFailedTitle,
      detail: loc.catalogScanFailedDetail,
      actionLabel: loc.catalogScanDismiss,
      onAction: widget._onDismiss,
    ),
    // Not a failure of this scan but of the pairing, so it reads as something
    // to fix rather than something to retry.
    CatalogRescanUnsupported() => _RowContent(
      tone: _ScanTone.attention,
      icon: TablerRegular.arrow_up_circle,
      title: loc.catalogScanUnsupportedTitle,
      detail: loc.catalogScanUnsupportedDetail,
      actionLabel: loc.catalogScanDismiss,
      onAction: widget._onDismiss,
    ),
    // Nothing was ever asked of the bridge, so the row says what is missing
    // instead of leaving the pull that started it with no answer.
    CatalogRescanNoHarness() => _RowContent(
      tone: _ScanTone.attention,
      icon: TablerRegular.plug_connected_x,
      title: loc.catalogScanNoHarnessTitle,
      detail: loc.catalogScanNoHarnessDetail,
      actionLabel: loc.catalogScanDismiss,
      onAction: widget._onDismiss,
    ),
  };
}

/// What a finished scan found, sessions first.
///
/// A clause counting nothing is dropped rather than joined, so an ordinary
/// result reads "3 new sessions" instead of trailing a zero, and a scan that
/// only turned up a project does not lead with the sessions it did not find.
///
/// Shared by the row and by the Settings toast, so one scan never reads two
/// different ways depending on where it is reported.
String catalogScanCountsLine({required AppLocalizations loc, required CatalogRescanCounts counts}) {
  final (sessions, projects) = switch (counts) {
    CatalogRescanDelta(:final newSessions, :final newProjects) => (
      newSessions == 0 ? null : loc.catalogScanNewSessionCount(newSessions),
      newProjects == 0 ? null : loc.catalogScanNewProjectCount(newProjects),
    ),
    // No delta to report, so the line names what the harnesses published
    // instead of implying every one of them is new.
    CatalogRescanTotals(:final sessions, :final projects) => (
      sessions == 0 ? null : loc.catalogScanSessionCount(sessions),
      projects == 0 ? null : loc.catalogScanProjectCount(projects),
    ),
  };
  return switch ((sessions, projects)) {
    (final sessions?, final projects?) => loc.catalogScanCountsJoined(sessions, projects),
    (final sessions?, null) => sessions,
    (null, final projects?) => projects,
    (null, null) => loc.catalogScanNothingNew,
  };
}

/// The colour family a scan state reads in.
///
/// Four tones rather than one per state, because several states share both a
/// severity and a treatment; the icon is what tells them apart.
enum _ScanTone() {
  working,
  done,
  attention,
  problem,
}

/// One state's whole presentation, resolved before anything is built.
class const _RowContent({
  required final _ScanTone tone,

  /// `null` means the leading slot shows a spinner instead, which is what the
  /// live states use.
  final IconData? icon,
  required final String title,
  required final String detail,
  required final String actionLabel,
  required final VoidCallback onAction,
});

/// The Figma result card: leading mark, two fixed lines, one tinted action.
class const _ScanCard({required final _RowContent content}) extends StatelessWidget {
  static const double _minHeight = 69;
  static const double _markSize = 22;
  // Figma's radial is 483.76px wide for a 69px vertical radius.
  static const double _glowScaleX = 7.011014492753623;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final wrapsText = _isTextEnlarged(context: context, style: prego.textTheme.textSm.medium);
    final icon = content.icon;
    if (icon == null) throw StateError("Terminal scan cards require an icon.");
    final clipShape = _deepScanCardShape(context);
    final outlineShape = _deepScanCardShape(
      context,
      side: BorderSide(color: colors.borderPrimary),
    );
    final (accent, markColor, actionColor) = switch (content.tone) {
      _ScanTone.working => throw StateError("Working scans require the loading card."),
      _ScanTone.done => (
        colors.bgSuccessSecondary,
        colors.textSuccessPrimary,
        colors.textSuccessPrimary,
      ),
      _ScanTone.attention => (
        colors.bgWarningSecondary,
        colors.fgWarningSecondary,
        colors.textWarningPrimary,
      ),
      _ScanTone.problem => (
        colors.bgErrorSolid,
        colors.fgErrorPrimary,
        colors.textErrorPrimary,
      ),
    };
    final textBlock = Padding(
      padding: const EdgeInsetsDirectional.only(top: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content.title,
            maxLines: wrapsText ? null : 1,
            overflow: wrapsText ? null : TextOverflow.ellipsis,
            style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: PregoSpacing.xxs),
          Text(
            content.detail,
            maxLines: wrapsText ? null : 1,
            overflow: wrapsText ? null : TextOverflow.ellipsis,
            style: prego.textTheme.textSm.medium.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    final action = Padding(
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xs),
      child: _ScanDismissButton(
        label: content.actionLabel,
        color: actionColor,
        onPressed: content.onAction,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Container(
            key: const ValueKey("catalog-scan-terminal-card"),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: colors.bgSurface5,
              shape: clipShape,
            ),
            foregroundDecoration: ShapeDecoration(shape: outlineShape),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1,
                  transform: const _TerminalGlowTransform(_glowScaleX),
                  colors: [
                    accent.withValues(alpha: 0),
                    accent.withValues(alpha: 0),
                    accent.withValues(alpha: 0.2),
                  ],
                  stops: const [0, 0.6, 1],
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: PregoSpacing.xl,
                  vertical: PregoSpacing.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      key: const ValueKey("catalog-scan-terminal-icon"),
                      dimension: _markSize,
                      child: Icon(icon, size: _markSize, color: markColor),
                    ),
                    const SizedBox(width: PregoSpacing.sm),
                    Expanded(
                      child: wrapsText
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                textBlock,
                                Align(alignment: AlignmentDirectional.centerEnd, child: action),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: textBlock),
                                const SizedBox(width: PregoSpacing.xs),
                                action,
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The feature-specific loading card from the Deep Scan Figma variants.
class const _ScanLoadingCard({
  required final String title,
  required final String supportingText,
  required final String cancelLabel,
  required final VoidCallback onCancel,
}) extends StatefulWidget {
  @override
  State<_ScanLoadingCard> createState() => _ScanLoadingCardState();
}

class _ScanLoadingCardState()
    extends State<_ScanLoadingCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  /// Figma coordinates both moving pieces on one ten-second looping timeline.
  static const Duration _period = Duration(seconds: 10);

  late final AnimationController _timeline = AnimationController(vsync: this, duration: _period);
  // The outlined sparkle rotates through five turns across the full timeline.
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
    // Reduced motion uses the intentional first frame, not an arbitrary pause.
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
    final wrapsText = _isTextEnlarged(context: context, style: prego.textTheme.textSm.medium);
    final clipShape = _deepScanCardShape(context);
    final outlineShape = _deepScanCardShape(
      context,
      side: BorderSide(color: colors.borderPrimary),
    );
    // The beam follows the theme-aware brand-gradient endpoint: white in dark
    // mode and Blue/400 in light mode, where it needs slightly less weight.
    final beamColor = colors.brandGradientTop;
    final beamOpacity = colors.brightness == Brightness.dark ? 0.6 : 0.48;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(PregoSpacing.xl),
        child: Container(
          key: const ValueKey("prego-deep-scan-card"),
          constraints: const BoxConstraints(minHeight: 69),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: colors.bgSurface5,
            shape: clipShape,
          ),
          foregroundDecoration: ShapeDecoration(shape: outlineShape),
          child: Stack(
            children: [
              PositionedDirectional(
                // The 104px mask starts 14px above the 69px viewport.
                top: -14,
                end: 21,
                width: _ScanLoadingPanel.width,
                height: _ScanLoadingPanel.height,
                child: RepaintBoundary(
                  key: const ValueKey("prego-deep-scan-panel"),
                  child: _ScanLoadingPanel(
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 69),
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
                              maxLines: wrapsText ? null : 1,
                              overflow: wrapsText ? null : TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(height: PregoSpacing.xxs),
                            Text(
                              widget.supportingText,
                              maxLines: wrapsText ? null : 1,
                              overflow: wrapsText ? null : TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PregoSpacing.lg),
                      _ScanCancelButton(
                        semanticLabel: widget.cancelLabel,
                        onPressed: widget.onCancel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The masked skeleton rows and travelling beam on the loading card's trailing side.
class const _ScanLoadingPanel({
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
              painter: _ScanLoadingSkeletonPainter(
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
                  painter: _ScanLoadingBeamPainter(
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

class _ScanLoadingSkeletonPainter({
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

      // Preserve Figma's group opacity for each row and its overlapping effects.
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
  bool shouldRepaint(_ScanLoadingSkeletonPainter oldDelegate) {
    return fillColor != oldDelegate.fillColor ||
        shadowColor != oldDelegate.shadowColor ||
        innerBorderColor != oldDelegate.innerBorderColor ||
        bottomShadowColor != oldDelegate.bottomShadowColor;
  }
}

class const _ScanLoadingBeamPainter({required final Color color, required final double opacity}) extends CustomPainter {
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
  bool shouldRepaint(_ScanLoadingBeamPainter oldDelegate) {
    return color != oldDelegate.color || opacity != oldDelegate.opacity;
  }
}

class const _ScanCancelButton({
  required final String semanticLabel,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final radius = BorderRadius.circular(PregoRadius.full);

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: _ScanFocusableAction(
          borderRadius: radius,
          onPressed: onPressed,
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
      ),
    );
  }
}

/// Deep Scan cards use one 24px silhouette in every terminal state. iOS gets
/// Flutter's native continuous superellipse, which is the platform equivalent
/// of Figma's roughly 60% corner smoothing; Android keeps the same radius with
/// standard circular corners.
ShapeBorder _deepScanCardShape(
  BuildContext context, {
  BorderSide side = BorderSide.none,
}) {
  const radius = BorderRadius.all(Radius.circular(PregoRadius.x4l));
  return Theme.of(context).platform == TargetPlatform.iOS
      ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
      : RoundedRectangleBorder(borderRadius: radius, side: side);
}

bool _isTextEnlarged({required BuildContext context, required TextStyle style}) {
  final fontSize = style.fontSize;
  return fontSize != null && MediaQuery.textScalerOf(context).scale(fontSize) > fontSize;
}

/// The label-only 76×36 action from the terminal Figma variants.
class const _ScanDismissButton({
  required final String label,
  required final Color color,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final radius = BorderRadius.circular(PregoRadius.full);
    final actionConstraints = MediaQuery.textScalerOf(context).scale(1) > 1
        ? const BoxConstraints(minWidth: 76, minHeight: 36)
        : const BoxConstraints.tightFor(width: 76, height: 36);

    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: _ScanFocusableAction(
          borderRadius: radius,
          onPressed: onPressed,
          child: ConstrainedBox(
            key: const ValueKey("catalog-scan-dismiss-action"),
            constraints: actionConstraints,
            child: PregoTappable(
              onTap: onPressed,
              borderRadius: radius,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) return colors.bgGrayPressed;
                if (states.contains(WidgetState.hovered)) return colors.bgGrayHover;
                return null;
              }),
              containerBuilder: (child) => ClipRRect(borderRadius: radius, child: child),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textSm.medium.copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _ScanFocusableAction({
  required final BorderRadius borderRadius,
  required final VoidCallback onPressed,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_ScanFocusableAction> createState() => _ScanFocusableActionState();
}

class _ScanFocusableActionState() extends State<_ScanFocusableAction> {
  bool _showFocusHighlight = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return FocusableActionDetector(
      onShowFocusHighlight: (show) => setState(() => _showFocusHighlight = show),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _showFocusHighlight
              ? [
                  BoxShadow(color: colors.focusRing, spreadRadius: 4),
                  BoxShadow(color: colors.bgSurface1, spreadRadius: 2),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Stretches Flutter's circular radial into Figma's wide, top-centred ellipse.
class const _TerminalGlowTransform(final double scaleX) extends GradientTransform {
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final centerX = bounds.center.dx;
    return Matrix4(
      scaleX,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      centerX * (1 - scaleX),
      0,
      0,
      1,
    );
  }
}
