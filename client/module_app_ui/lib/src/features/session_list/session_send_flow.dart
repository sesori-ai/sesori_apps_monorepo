part of "session_list_action_dispatcher.dart";

/// Opens a session from an alert, without a context: the alert can outlive
/// the page that raised it.
typedef SentSessionOpener = void Function({
  required String projectId,
  required String projectName,
  required Session session,
});

/// Long enough to reach an alert's action: Stop or Open.
const Duration _sendOutcomeAlertDuration = Duration(seconds: 8);

/// Sends [source] into the session the user picks. A running source cannot
/// write its summary, so it is answered with an alert that offers Stop. The
/// alert presenter is captured first, so the outcome still shows after the
/// user leaves the page.
void _sendToAnother({
  required BuildContext context,
  required SessionActionsCubit actions,
  required Session source,
  required bool isRunning,
  required SessionSearchCubitFactory createSearch,
  required SentSessionOpener openSession,
}) {
  final loc = context.loc;
  final presenter = PregoPopupAlertPresenter.of(context);
  final sourceName = _sessionName(loc: loc, session: source);
  if (isRunning) {
    presenter.show(
      title: loc.sendSessionSourceBusy(sourceName),
      variant: PregoPopupAlertsNotificationsVariant.warning,
      content: PregoPopupAlertContent(
        primaryAction: PregoPopupAlertsNotificationsAction(
          label: loc.sendSessionStop,
          onPressed: () {
            presenter.dismiss();
            unawaited(() async {
              if (await actions.stopSession(sessionId: source.id)) return;
              presenter.show(
                title: loc.sendSessionStopFailed(sourceName),
                variant: PregoPopupAlertsNotificationsVariant.error,
              );
            }());
          },
        ),
      ),
      duration: _sendOutcomeAlertDuration,
    );
    return;
  }
  unawaited(() async {
    final choice = await showSendSessionSheet(context: context, source: source, createSearch: createSearch);
    if (choice == null) return;
    final target = choice.target;
    final targetName = _sessionName(loc: loc, session: target.session);
    presenter.show(
      title: loc.sendSessionSending(sourceName, targetName),
      variant: PregoPopupAlertsNotificationsVariant.loading,
    );
    final result = await actions.sendToSession(sourceSessionId: source.id, targetSessionId: target.session.id);
    final open = PregoPopupAlertsNotificationsAction(
      label: loc.sendSessionOpen,
      onPressed: () {
        presenter.dismiss();
        openSession(
          projectId: target.project.id,
          projectName: projectDisplayName(loc: loc, project: target.project),
          session: target.session,
        );
      },
    );
    switch (result) {
      case SendToSessionSent():
        presenter.show(
          title: loc.sendSessionSent(targetName),
          variant: PregoPopupAlertsNotificationsVariant.success,
          content: PregoPopupAlertContent(primaryAction: open),
          duration: _sendOutcomeAlertDuration,
        );
      case SendToSessionUnconfirmed():
        presenter.show(
          title: loc.sendSessionUnconfirmed(targetName),
          variant: PregoPopupAlertsNotificationsVariant.warning,
          content: PregoPopupAlertContent(primaryAction: open),
          duration: _sendOutcomeAlertDuration,
        );
      case SendToSessionUnsupported():
        presenter.show(
          title: loc.sendSessionUnsupported,
          variant: PregoPopupAlertsNotificationsVariant.warning,
          content: PregoPopupAlertContent(
            primaryAction: PregoPopupAlertsNotificationsAction(
              label: loc.bridgeUpdateHowTo,
              onPressed: () {
                presenter.dismiss();
                if (context.mounted) unawaited(showBridgeUpdateSheet(context: context));
              },
            ),
          ),
        );
      case SendToSessionRefused(:final code, :final message):
        presenter.show(
          title: _refusalText(loc: loc, code: code, message: message, sourceName: sourceName, targetName: targetName),
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      case SendToSessionFailed():
        presenter.show(
          title: loc.sendSessionFailed(sourceName),
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      case SendToSessionComputerSwitched():
        // The user moved to another computer; this outcome is not about it.
        break;
    }
  }());
}

String _refusalText({
  required AppLocalizations loc,
  required SendToSessionErrorCode code,
  required String? message,
  required String sourceName,
  required String targetName,
}) => switch (code) {
  SendToSessionErrorCode.sameSession => loc.sendSessionFailedSameSession,
  SendToSessionErrorCode.sourceArchived => loc.sendSessionFailedSourceArchived(sourceName),
  SendToSessionErrorCode.targetArchived => loc.sendSessionFailedTargetArchived(targetName),
  SendToSessionErrorCode.sourceNotRoot => loc.sendSessionFailedSourceNotRoot(sourceName),
  SendToSessionErrorCode.sourceBusy => loc.sendSessionFailedSourceBusy(sourceName),
  SendToSessionErrorCode.sourceAwaitingInput => loc.sendSessionFailedSourceAwaitingInput(sourceName),
  SendToSessionErrorCode.sourceUnavailable => loc.sendSessionFailedSourceUnavailable(sourceName),
  SendToSessionErrorCode.sourceEmpty => loc.sendSessionFailedSourceEmpty(sourceName),
  SendToSessionErrorCode.summaryStopped => loc.sendSessionFailedSummaryStopped,
  SendToSessionErrorCode.summaryFailed => loc.sendSessionFailedSummaryFailed,
  SendToSessionErrorCode.summaryTimedOut => loc.sendSessionFailedSummaryTimedOut,
  SendToSessionErrorCode.summaryMissing => loc.sendSessionFailedSummaryMissing,
  SendToSessionErrorCode.transcriptUnavailable => loc.sendSessionFailedTranscriptUnavailable(sourceName),
  SendToSessionErrorCode.targetRefused => switch (message) {
    null => loc.sendSessionFailedTargetRefused(targetName),
    final reason => loc.sendSessionFailedTargetRefusedReason(reason),
  },
  SendToSessionErrorCode.unknown => loc.sendSessionFailed(sourceName),
};
