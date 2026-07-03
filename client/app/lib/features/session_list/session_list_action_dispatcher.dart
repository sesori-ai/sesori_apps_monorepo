part of "session_list_screen.dart";

class SessionListActionDispatcher {
  const SessionListActionDispatcher();

  void showSessionActions({required BuildContext context, required Session session}) {
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final isArchived = session.time?.archived != null;
    final state = cubit.state;
    final isUnseen = state is SessionListLoaded
        ? (state.unseenBySessionId[session.id] ?? session.unseen)
        : session.unseen;

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
              leading: Icon(isUnseen ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined),
              title: Text(isUnseen ? loc.sessionListMarkRead : loc.sessionListMarkUnread),
              onTap: () {
                sheetContext.pop();
                unawaited(cubit.markSessionSeen(sessionId: session.id, read: isUnseen));
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
              leading: Icon(Icons.delete_outlined, color: context.prego.colors.fgErrorPrimary),
              title: Text(
                loc.sessionListDelete,
                style: TextStyle(color: context.prego.colors.fgErrorPrimary),
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

  void handleSessionSwipe({required BuildContext context, required Session session}) {
    final cubit = context.read<SessionListCubit>();
    if (session.time?.archived != null) {
      _unarchiveSession(context: context, cubit: cubit, sessionId: session.id);
    } else {
      _showArchiveSheet(context: context, cubit: cubit, session: session);
    }
  }
}
