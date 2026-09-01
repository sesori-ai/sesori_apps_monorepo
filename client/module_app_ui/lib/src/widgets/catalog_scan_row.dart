import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../l10n/app_localizations.dart";

/// How long the row takes to grow in or fold away.
const Duration _revealDuration = Duration(milliseconds: 260);

/// The catalog scan reported as one quiet row above a list.
///
/// Deliberately not an inline alert: that component paints the inverted
/// foreground and is built to interrupt, which is wrong for something a pull
/// starts and that clears itself. This is a tinted card in the state's own
/// colour family, weighted to sit above the list rather than on top of it.
///
/// Its height never changes with the state. The supporting line always occupies
/// a row, so a scan that starts before it can name a harness does not shove the
/// list down again the moment the first progress event lands.
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

class _CatalogScanRowState() extends State<CatalogScanRow> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealDuration,
    // A scan already running when this mounts is not news: the list is being
    // revisited mid-run, so the row is simply there rather than arriving.
    value: _hasContent ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
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
    // Drops the retained card once it has finished folding away. Without this
    // its labels and its live action button stay mounted at zero height, where
    // a keyboard or screen reader can still reach an invisible control.
    _reveal.addStatusListener(_onRevealStatus);
  }

  @override
  void didUpdateWidget(CatalogScanRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Read per change rather than once: the OS preference can be turned on
    // while this row is on screen.
    _reveal.duration = context.isReducedMotion ? Duration.zero : _revealDuration;
    if (_hasContent) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _shown == null) return;
    setState(() => _shown = null);
  }

  @override
  void dispose() {
    _reveal.removeStatusListener(_onRevealStatus);
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
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.prego.spacing.lg,
            context.prego.spacing.md,
            context.prego.spacing.lg,
            context.prego.spacing.sm,
          ),
          // Announced when it appears without moving focus, the same treatment
          // the connection banner uses: a scan started by a pull finishes with
          // no other signal that it is done. Every state announces except the
          // running one, whose session count changes with each enumerated
          // session and would otherwise interrupt a screen reader hundreds of
          // times during one scan.
          child: Semantics(
            container: true,
            liveRegion: widget._scan is! CatalogRescanRunning,
            child: _ScanCard(content: shown),
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

/// The tinted card itself: leading mark, two fixed lines, one action.
class const _ScanCard({required final _RowContent content}) extends StatelessWidget {
  /// Leading glyph and spinner size. Smaller than an alert's, because this row
  /// reports rather than interrupts.
  static const double _markSize = 18;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final (background, foreground) = switch (content.tone) {
      _ScanTone.working => (colors.bgSecondary, colors.fgBrandPrimary),
      _ScanTone.done => (colors.bgSuccessPrimary, colors.fgSuccessPrimary),
      _ScanTone.attention => (colors.bgWarningPrimary, colors.fgWarningPrimary),
      _ScanTone.problem => (colors.bgErrorPrimary, colors.fgErrorPrimary),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        border: Border.all(color: colors.borderSecondary),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PregoSpacing.lg,
          PregoSpacing.lg,
          PregoSpacing.md,
          PregoSpacing.lg,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: _markSize,
              child: switch (content.icon) {
                final icon? => Icon(icon, size: _markSize, color: foreground),
                null => PregoActivityIndicator(color: foreground),
              },
            ),
            const SizedBox(width: PregoSpacing.lg),
            Expanded(
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
                  // Always rendered, never conditional: the detail arrives one
                  // event after the row does, and a line appearing under it
                  // would move the whole list a second time.
                  Text(
                    content.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textXs.regular.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PregoSpacing.sm),
            PregoButtonsSolid(
              label: content.actionLabel,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.sm,
              onPressed: content.onAction,
            ),
          ],
        ),
      ),
    );
  }
}
