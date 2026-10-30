import "dart:async";
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../l10n/app_localizations.dart";

/// How long the card takes to rise in or sink away.
const Duration _revealDuration = Duration(milliseconds: 260);
const Curve _revealEaseOut = Cubic(0.23, 1, 0.32, 1);
// How far the card rises as it fades in, as a fraction of its own height.
const double _revealRise = 0.2;
// A compact optical entrance: close enough to full size that text stays stable,
// with just enough blur to soften the arrival without looking glassy.
const double _entranceScaleFrom = 0.97;
const double _entranceBlurSigma = 2;
// Keep the leading footprint identical when loading becomes a result.
const double _scanMarkSize = 20;
const Duration _startupWaitThreshold = Duration(seconds: 3);
// Both Deep Scan cards rest at this height at standard text size.
const double _cardMinHeight = 69;

/// The room a list hosting a floating [CatalogScanRow] reserves after its last
/// row, so that row scrolls fully clear of the card. Reserved whether or not a
/// scan is showing, so the card coming and going never changes the list.
const double catalogScanRowClearance = _cardMinHeight + 2 * PregoSpacing.xl;

/// The catalog scan reported as one quiet card floating over a list.
///
/// Hosts float it over the bottom of the list instead of giving it a place in
/// the list, so neither its arrival nor its exit moves a row or a filter chip
/// under the user's finger. It rises in and sinks away where it floats rather
/// than growing or folding, and only the card itself takes pointer events.
///
/// Live scans use the coordinated loading card designed for this flow;
/// terminal outcomes keep their severity-tinted report cards. The card has no
/// controls: the scan clears itself once settled, and the card fades away.
class const CatalogScanRow({
  super.key,

  /// The scan to report, read from the hosting list's own state so the row
  /// re-renders with the list rather than subscribing separately.
  required final CatalogRescanState _scan,
}) extends StatefulWidget {
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
  late final Animation<Offset> _rise = Tween(
    begin: const Offset(0, _revealRise),
    end: Offset.zero,
  ).animate(_curve);

  /// The last content worth showing, kept while the card fades away.
  ///
  /// Without it the card would vanish on the frame the scan cleared.
  _RowContent? _shown;

  Timer? _startupWaitTimer;
  String? _startupWaitPluginName;
  bool _startupWaitElapsed = false;

  /// Whether the current scan has anything to report. Decided from the scan
  /// alone, so the animation can be driven from lifecycle callbacks rather than
  /// from [build], where starting a controller races its own frame.
  bool get _hasContent => widget._scan is! CatalogRescanIdle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drops the retained card once it has finished fading away. Without this
    // its labels stay mounted at zero opacity, where a screen reader can still
    // reach invisible text.
    _reveal.addStatusListener(_onRevealStatus);
    _syncStartupWait();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReducedMotionPreference();
  }

  @override
  void didUpdateWidget(CatalogScanRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStartupWait();
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

  void _syncStartupWait() {
    final pluginName = switch (widget._scan) {
      CatalogRescanStarting(:final activePluginName) => activePluginName,
      CatalogRescanIdle() ||
      CatalogRescanPreparingOne() ||
      CatalogRescanReading() ||
      CatalogRescanSaving() ||
      CatalogRescanSucceeded() ||
      CatalogRescanPartlyFailed() ||
      CatalogRescanFailed() => null,
    };
    if (pluginName == _startupWaitPluginName && (_startupWaitTimer != null || _startupWaitElapsed)) return;
    _startupWaitTimer?.cancel();
    _startupWaitTimer = null;
    _startupWaitPluginName = pluginName;
    _startupWaitElapsed = false;
    if (pluginName == null) return;
    _startupWaitTimer = Timer(_startupWaitThreshold, () {
      _startupWaitTimer = null;
      if (!mounted) return;
      final stillWaitingForSameHarness = switch (widget._scan) {
        CatalogRescanStarting(:final activePluginName) => activePluginName == pluginName,
        CatalogRescanIdle() ||
        CatalogRescanPreparingOne() ||
        CatalogRescanReading() ||
        CatalogRescanSaving() ||
        CatalogRescanSucceeded() ||
        CatalogRescanPartlyFailed() ||
        CatalogRescanFailed() => false,
      };
      if (!stillWaitingForSameHarness) return;
      setState(() => _startupWaitElapsed = true);
    });
  }

  @override
  void dispose() {
    _startupWaitTimer?.cancel();
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

    // A departing card takes no taps meant for the rows it uncovers, and a
    // screen reader no longer reaches its fading text.
    return ExcludeSemantics(
      excluding: !_hasContent,
      child: IgnorePointer(
        ignoring: !_hasContent,
        child: SlideTransition(
          position: _rise,
          child: FadeTransition(
            opacity: _curve,
            // Announced when it appears without moving focus, the same treatment
            // the connection banner uses: a scan started by a pull finishes with
            // no other signal that it is done. Every state announces except the
            // reading one, whose session count changes with each enumerated
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
                  alignment: Alignment.bottomCenter,
                  scale: scale,
                  child: filteredChild,
                );
              },
              // AnimatedBuilder retains this subtree while only the composited
              // entrance transform and its short-lived image filter change.
              child: Semantics(
                container: true,
                liveRegion: widget._scan is! CatalogRescanReading,
                child: shown.tone == _ScanTone.working
                    ? _ScanLoadingCard(
                        title: shown.title,
                        supportingText: shown.detail,
                        wrapSupportingText: shown.wrapDetail,
                      )
                    : Padding(
                        padding: const EdgeInsetsDirectional.all(PregoSpacing.xl),
                        child: _ScanCard(content: shown),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The one place the scan state decides how the row reads.
  ///
  /// `null` is the idle row, which fades away to nothing.
  _RowContent? _contentFor({required AppLocalizations loc, required CatalogRescanState scan}) => switch (scan) {
    CatalogRescanIdle() => null,
    CatalogRescanPreparingOne(:final pendingPluginName, :final finishedHarnessCount, :final pluginIds) => _RowContent(
      tone: _ScanTone.working,
      title: loc.catalogScanRunningTitle(finishedHarnessCount, pluginIds.length),
      detail: loc.catalogScanPreparingOneDetail(pendingPluginName),
    ),
    CatalogRescanStarting(:final activePluginName, :final finishedHarnessCount, :final pluginIds) => _RowContent(
      tone: _ScanTone.working,
      title: _startupWaitElapsed
          ? loc.catalogScanWaitingTitle(activePluginName, finishedHarnessCount, pluginIds.length)
          : loc.catalogScanRunningTitle(finishedHarnessCount, pluginIds.length),
      detail: _startupWaitElapsed
          ? loc.catalogScanWaitingDetail(activePluginName)
          : loc.catalogScanStartingDetail(activePluginName),
      wrapDetail: _startupWaitElapsed,
    ),
    CatalogRescanReading(:final activePluginName, :final sessionsSeen, :final finishedHarnessCount, :final pluginIds) =>
      _RowContent(
        tone: _ScanTone.working,
        title: loc.catalogScanRunningTitle(finishedHarnessCount, pluginIds.length),
        detail: sessionsSeen == 0
            ? loc.catalogScanReadingDetail(activePluginName)
            : loc.catalogScanReadingCountDetail(activePluginName, sessionsSeen),
      ),
    CatalogRescanSaving(:final activePluginName, :final finishedHarnessCount, :final pluginIds) => _RowContent(
      tone: _ScanTone.working,
      title: loc.catalogScanRunningTitle(finishedHarnessCount, pluginIds.length),
      detail: loc.catalogScanSavingDetail(activePluginName),
    ),
    CatalogRescanSucceeded(:final counts) => _RowContent(
      tone: _ScanTone.done,
      icon: TablerRegular.circle_check,
      title: loc.catalogScanCompleteTitle,
      detail: _countsLine(loc: loc, counts: counts),
    ),
    CatalogRescanPartlyFailed(:final succeededCount, :final failedCount) => _RowContent(
      tone: _ScanTone.attention,
      icon: TablerRegular.alert_triangle,
      title: loc.catalogScanPartlyFailedTitle,
      detail: loc.catalogScanPartlyFailedDetail(failedCount, succeededCount + failedCount),
    ),
    // The bridge's own error text never reaches the client, so the row names
    // the log that has it rather than guessing at a cause.
    CatalogRescanFailed() => _RowContent(
      tone: _ScanTone.problem,
      icon: TablerRegular.alert_circle,
      title: loc.catalogScanFailedTitle,
      detail: loc.catalogScanFailedDetail,
    ),
  };
}

/// What a finished scan found, sessions first.
///
/// A clause counting nothing is dropped rather than joined, so an ordinary
/// result reads "3 new sessions" instead of trailing a zero, and a scan that
/// only turned up a project does not lead with the sessions it did not find.
///
String _countsLine({required AppLocalizations loc, required CatalogRescanCounts counts}) {
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
  final bool wrapDetail = false,
});

/// The Figma result card: leading mark and two fixed lines.
class const _ScanCard({required final _RowContent content}) extends StatelessWidget {
  static const double _minHeight = _cardMinHeight;
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
    final (accent, markColor) = switch (content.tone) {
      _ScanTone.working => throw StateError("Working scans require the loading card."),
      _ScanTone.done => (colors.bgSuccessSecondary, colors.textSuccessPrimary),
      _ScanTone.attention => (colors.bgWarningSecondary, colors.fgWarningSecondary),
      _ScanTone.problem => (colors.bgErrorSolid, colors.fgErrorPrimary),
    };
    final textBlock = Column(
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      key: const ValueKey("catalog-scan-terminal-icon"),
                      dimension: _scanMarkSize,
                      child: Icon(icon, size: _scanMarkSize, color: markColor),
                    ),
                    const SizedBox(width: PregoSpacing.sm),
                    Expanded(child: textBlock),
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
  required final bool wrapSupportingText,
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

    // The margin outside the Material, which absorbs hits, so taps there reach
    // the list the card floats over.
    return Padding(
      padding: const EdgeInsetsDirectional.all(PregoSpacing.xl),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          key: const ValueKey("prego-deep-scan-card"),
          constraints: const BoxConstraints(minHeight: _cardMinHeight),
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
                  constraints: const BoxConstraints(minHeight: _cardMinHeight),
                  child: Row(
                    children: [
                      RotationTransition(
                        key: const ValueKey("prego-deep-scan-loader"),
                        turns: _loaderTurns,
                        child: PregoAiLoader(
                          size: _scanMarkSize,
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
                              maxLines: wrapsText || widget.wrapSupportingText ? null : 1,
                              overflow: wrapsText || widget.wrapSupportingText ? null : TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(height: PregoSpacing.xxs),
                            Text(
                              widget.supportingText,
                              maxLines: wrapsText || widget.wrapSupportingText ? null : 1,
                              overflow: wrapsText || widget.wrapSupportingText ? null : TextOverflow.ellipsis,
                              style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
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
  // Traced from the illustration's artwork, not a UI radius.
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
