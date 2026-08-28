import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../l10n/app_localizations.dart";
import "../extensions/build_context_x.dart";

/// How long the row takes to grow in or fold away.
const Duration _revealDuration = Duration(milliseconds: 260);
const Curve _revealEaseOut = Cubic(0.23, 1, 0.32, 1);
// A compact optical entrance: close enough to full size that text stays stable,
// with just enough blur to connect the card to the pull without looking glassy.
const double _entranceScaleFrom = 0.97;
const double _entranceBlurSigma = 2;

/// The catalog scan reported as one quiet row above a list.
///
/// Live scans use the coordinated PREGO loading alert designed for this flow;
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

class _CatalogScanRowState() extends State<CatalogScanRow>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
                ? PregoInlineAlertsNotifications(
                    type: PregoInlineAlertsNotificationsType.loading,
                    title: shown.title,
                    supportingText: shown.detail,
                    onClose: shown.onAction,
                    closeSemanticLabel: shown.actionLabel,
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
enum _ScanTone() { working, done, attention, problem }

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
  static const double _height = 69;
  static const double _markSize = 22;
  // Figma's radial is 483.76px wide for a 69px vertical radius.
  static const double _glowScaleX = 7.011014492753623;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final clipShape = _deepScanCardShape(context);
    final outlineShape = _deepScanCardShape(
      context,
      side: BorderSide(color: colors.borderPrimary),
    );
    final (accent, markColor, actionColor) = switch (content.tone) {
      // The working tone is rendered by PREGO's loading alert above. Keeping
      // this branch exhaustive makes the terminal card's token mapping honest.
      _ScanTone.working => (colors.bgBrandSolid, colors.fgBrandPrimary, colors.textBrandSecondary),
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

    return SizedBox(
      height: _height,
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
                  child: switch (content.icon) {
                    final icon? => Icon(icon, size: _markSize, color: markColor),
                    null => PregoActivityIndicator(color: markColor),
                  },
                ),
                const SizedBox(width: PregoSpacing.sm),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(top: 1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                content.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: prego.textTheme.textSm.medium.copyWith(color: colors.textPrimary),
                              ),
                              const SizedBox(height: PregoSpacing.xxs),
                              Text(
                                content.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: prego.textTheme.textSm.medium.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: PregoSpacing.xs),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xs),
                        child: _ScanDismissButton(
                          label: content.actionLabel,
                          color: actionColor,
                          onPressed: content.onAction,
                        ),
                      ),
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

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey("catalog-scan-dismiss-action"),
          width: 76,
          height: 36,
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
