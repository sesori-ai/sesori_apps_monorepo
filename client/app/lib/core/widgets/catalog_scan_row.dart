import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../l10n/app_localizations.dart";
import "../extensions/build_context_x.dart";

/// The catalog scan reported as one row above a list.
///
/// Every scan state renders through the shared inline alert, so the row picks
/// up the design system's tinted card, spinner, and action buttons rather than
/// owning a bespoke treatment. The scan is one aggregate however many harnesses
/// take part, so this is one row rather than one per harness.
///
/// Sized by its state: [CatalogRescanIdle] takes no space at all, so a host can
/// mount the row unconditionally and let the scan decide whether it shows.
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
}) extends StatelessWidget {
  /// The pull-to-refresh second stage that starts a scan, carrying the captions
  /// that say what crossing the deeper threshold will do.
  ///
  /// Lives beside the row so the gesture that starts a scan and the row that
  /// reports it stay worded together, and every list gets the same invitation.
  static PregoDeepRefresh deepRefresh({required BuildContext context, required VoidCallback onStart}) {
    return PregoDeepRefresh(
      onDeepRefresh: onStart,
      pullCaption: context.loc.catalogScanPullCaption,
      deepCaption: context.loc.catalogScanDeepCaption,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(loc: context.loc);
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.prego.spacing.lg,
        context.prego.spacing.md,
        context.prego.spacing.lg,
        context.prego.spacing.sm,
      ),
      // Announced when it appears without moving focus, the same treatment the
      // connection banner uses: a scan started by a pull finishes with no other
      // signal that it is done.
      child: Semantics(
        container: true,
        liveRegion: true,
        child: PregoInlineAlertsNotifications(
          type: content.type,
          title: content.title,
          supportingText: content.detail,
          icon: content.icon,
          secondaryAction: PregoInlineAlertsNotificationsAction(
            label: content.actionLabel,
            onPressed: content.onAction,
          ),
        ),
      ),
    );
  }

  /// The one place the scan state decides how the row reads.
  ///
  /// `null` is the idle row, which renders nothing.
  ({
    PregoInlineAlertsNotificationsType type,
    String title,
    String? detail,
    IconData? icon,
    String actionLabel,
    VoidCallback onAction,
  })?
  _contentFor({required AppLocalizations loc}) => switch (_scan) {
    CatalogRescanIdle() => null,
    // The spinner the loading type brings is the progress report: a scan has
    // no total to count towards, so there is nothing to fill a bar with.
    CatalogRescanStarting() => (
      type: PregoInlineAlertsNotificationsType.loading,
      title: loc.catalogScanRunningTitle,
      detail: null,
      icon: null,
      actionLabel: loc.catalogScanCancel,
      onAction: _onCancel,
    ),
    CatalogRescanRunning(:final activePluginName, :final sessionsSeen) => (
      type: PregoInlineAlertsNotificationsType.loading,
      title: loc.catalogScanRunningTitle,
      detail: loc.catalogScanRunningDetail(activePluginName, sessionsSeen),
      icon: null,
      actionLabel: loc.catalogScanCancel,
      onAction: _onCancel,
    ),
    CatalogRescanSucceeded(:final counts) => (
      type: PregoInlineAlertsNotificationsType.success,
      title: loc.catalogScanCompleteTitle,
      detail: _countsLine(loc: loc, counts: counts),
      icon: null,
      actionLabel: loc.catalogScanDismiss,
      onAction: _onDismiss,
    ),
    CatalogRescanPartlyFailed(:final succeededCount, :final failedCount) => (
      type: PregoInlineAlertsNotificationsType.warning,
      title: loc.catalogScanPartlyFailedTitle,
      detail: loc.catalogScanPartlyFailedDetail(failedCount, succeededCount + failedCount),
      icon: null,
      actionLabel: loc.catalogScanDismiss,
      onAction: _onDismiss,
    ),
    // The bridge's own error text never reaches the client, so the row names
    // the log that has it rather than guessing at a cause.
    CatalogRescanFailed() => (
      type: PregoInlineAlertsNotificationsType.error,
      title: loc.catalogScanFailedTitle,
      detail: loc.catalogScanFailedDetail,
      icon: null,
      actionLabel: loc.catalogScanDismiss,
      onAction: _onDismiss,
    ),
    // Not a failure of this scan but of the pairing, so it reads as something
    // to fix rather than something to retry.
    CatalogRescanUnsupported() => (
      type: PregoInlineAlertsNotificationsType.warning,
      title: loc.catalogScanUnsupportedTitle,
      detail: loc.catalogScanUnsupportedDetail,
      icon: TablerRegular.arrow_up_circle,
      actionLabel: loc.catalogScanDismiss,
      onAction: _onDismiss,
    ),
  };

  /// What a finished scan found, sessions first.
  ///
  /// The projects clause is dropped when nothing new landed in one, so an
  /// ordinary result reads "3 new sessions" rather than trailing a zero.
  String _countsLine({required AppLocalizations loc, required CatalogRescanCounts counts}) {
    final (sessions, projects) = switch (counts) {
      CatalogRescanDelta(:final newSessions, :final newProjects) => (
        loc.catalogScanNewSessionCount(newSessions),
        newProjects == 0 ? null : loc.catalogScanNewProjectCount(newProjects),
      ),
      // No delta to report, so the row names what the harnesses published
      // instead of implying every one of them is new.
      CatalogRescanTotals(:final sessions, :final projects) => (
        loc.catalogScanSessionCount(sessions),
        loc.catalogScanProjectCount(projects),
      ),
    };
    return switch (projects) {
      final projects? => loc.catalogScanCountsJoined(sessions, projects),
      null => sessions,
    };
  }
}
