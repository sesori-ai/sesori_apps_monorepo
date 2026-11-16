import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";

/// Opens the session a handoff marker or card names, in its own project and,
/// when archived, read-only, as the session list opens it. The handoff names
/// only the session, so the page reads it first; one that can't be read, as
/// when it was deleted, answers the tap with an alert.
Future<void> openHandoffSession({required BuildContext context, required String sessionId}) async {
  // A second tap while the first reads the session would open it twice; the
  // first tap's answer is on its way.
  if (!_reading.add(sessionId)) return;
  try {
    final scope = SessionDetailPresentationScope.read(context);
    final alerts = PregoPopupAlertPresenter.of(context);
    final unavailable = context.loc.transcriptHandoffSessionUnavailable;
    final session = await context.read<SessionDetailCubit>().linkedSession(sessionId: sessionId);
    if (!context.mounted) return;
    if (session == null) {
      alerts.show(title: unavailable, variant: PregoPopupAlertsNotificationsVariant.error);
      return;
    }
    scope.openSession(
      projectId: session.projectID,
      sessionId: session.id,
      sessionTitle: session.title,
      readOnly: session.time?.archived != null,
    );
  } finally {
    _reading.remove(sessionId);
  }
}

final _reading = <String>{};

/// A session's title as a handoff names it, or the localized stand-in.
String handoffSessionName({required BuildContext context, required String? title}) {
  final trimmed = title?.trim();
  return trimmed == null || trimmed.isEmpty ? context.loc.transcriptHandoffAnotherSession : trimmed;
}
