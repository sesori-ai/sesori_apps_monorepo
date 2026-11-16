import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";

/// Opens the session a handoff marker or card names, in its own project and,
/// when archived, read-only, as the session list opens it. The handoff names
/// only the session, so the page reads it first; one that can't be read, as
/// when it was deleted, answers the tap with an alert.
Future<void> openHandoffSession({required BuildContext context, required String sessionId}) {
  final scope = SessionDetailPresentationScope.read(context);
  return openLinkedSession(
    context: context,
    sessionId: sessionId,
    open: ({required session}) => scope.openSession(
      projectId: session.projectID,
      sessionId: session.id,
      sessionTitle: session.title,
      readOnly: session.time?.archived != null,
    ),
  );
}

/// Goes back to a fork's origin, read-only when archived, as
/// [openHandoffSession] opens a handoff's session.
Future<void> openForkOrigin({required BuildContext context, required String sessionId}) {
  final scope = SessionDetailPresentationScope.read(context);
  return openLinkedSession(
    context: context,
    sessionId: sessionId,
    open: ({required session}) => scope.returnToSession(
      projectId: session.projectID,
      sessionId: session.id,
      sessionTitle: session.title,
      readOnly: session.time?.archived != null,
    ),
  );
}

/// Reads [sessionId] and hands it to [open], so a link opens an archived
/// session read-only from the start; one that can't be read, as when it was
/// deleted, answers the tap with an alert.
Future<void> openLinkedSession({
  required BuildContext context,
  required String sessionId,
  required void Function({required Session session}) open,
}) async {
  // A second tap while the first reads the session would open it twice; the
  // first tap's answer is on its way.
  if (!_reading.add(sessionId)) return;
  try {
    final alerts = PregoPopupAlertPresenter.of(context);
    final unavailable = context.loc.transcriptHandoffSessionUnavailable;
    final session = await context.read<SessionDetailCubit>().linkedSession(sessionId: sessionId);
    if (!context.mounted) return;
    if (session == null) {
      alerts.show(title: unavailable, variant: PregoPopupAlertsNotificationsVariant.error);
      return;
    }
    open(session: session);
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
