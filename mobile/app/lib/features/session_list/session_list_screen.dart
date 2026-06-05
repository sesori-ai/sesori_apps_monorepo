import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";
import "../../l10n/app_localizations.dart";
import "rename_session_dialog.dart";
import "session_list_cubit_provider.dart";
import "session_list_scaffold.dart";

part "session_list_actions.dart";
part "session_cleanup_dialogs.dart";
part "session_force_dialog.dart";

class SessionListScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const SessionListScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return SessionListCubitProvider(
      projectId: projectId,
      child: _SessionListBody(
        projectId: projectId,
        projectName: projectName,
      ),
    );
  }
}

class _SessionListBody extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const _SessionListBody({required this.projectId, this.projectName});

  void _showSessionActions({required BuildContext context, required Session session}) {
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final isArchived = session.time?.archived != null;

    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(loc.rename),
              onTap: () {
                sheetContext.pop();
                showRenameSessionDialog(
                  context: context,
                  session: session,
                  cubit: cubit,
                );
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(isArchived ? loc.sessionListUnarchive : loc.sessionListArchive),
              onTap: () {
                sheetContext.pop();
                if (isArchived) {
                  _unarchiveSession(context: context, cubit: cubit, sessionId: session.id);
                } else {
                  _showArchiveSheet(context: context, cubit: cubit, session: session);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: context.zyra.colors.fgErrorPrimary),
              title: Text(
                loc.sessionListDelete,
                style: TextStyle(color: context.zyra.colors.fgErrorPrimary),
              ),
              onTap: () {
                sheetContext.pop();
                _showDeleteSheet(context: context, cubit: cubit, session: session);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionListScaffold(
      projectName: projectName,
      onNewSession: () {
        context.pushRoute(AppRoute.newSession(projectId: projectId));
      },
      onSessionTap: (session) {
        context.pushRoute(
          AppRoute.sessionDetail(
            projectId: projectId,
            sessionId: session.id,
            sessionTitle: session.title ?? "",
            readOnly: false,
          ),
        );
      },
      onSessionLongPress: (session) => _showSessionActions(context: context, session: session),
      onSessionSwipe: (session) {
        final cubit = context.read<SessionListCubit>();
        if (session.time?.archived != null) {
          _unarchiveSession(context: context, cubit: cubit, sessionId: session.id);
        } else {
          _showArchiveSheet(context: context, cubit: cubit, session: session);
        }
      },
    );
  }
}
