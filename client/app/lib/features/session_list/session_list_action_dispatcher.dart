part of "session_list_screen.dart";

class SessionListActionDispatcher {
  const SessionListActionDispatcher();

  /// The long-press actions for [session], rendered by [SessionTile] in a
  /// [PregoAnchorMenu] anchored to the row.
  ///
  /// [PregoAnchorMenu] dismisses the menu before running an entry's `onTap`, so
  /// each of these acts against the still-mounted row rather than a popped
  /// route — the sheets they raise (archive, delete) push on top of the list.
  List<PregoMenuEntry> sessionMenuEntries({required BuildContext context, required Session session}) {
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final isArchived = session.time?.archived != null;
    final isUnseen = _isUnseen(cubit: cubit, session: session);

    return [
      PregoMenuItem(
        leadingIcon: TablerRegular.pencil,
        title: loc.rename,
        subtitle: null,
        isSelected: false,
        onTap: () => showRenameSessionDialog(context: context, session: session, cubit: cubit),
      ),
      PregoMenuItem(
        leadingIcon: isUnseen ? TablerRegular.mail_opened : TablerRegular.mail,
        title: isUnseen ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
        subtitle: null,
        isSelected: false,
        onTap: () => unawaited(cubit.markSessionSeen(sessionId: session.id, read: isUnseen)),
      ),
      PregoMenuItem(
        leadingIcon: isArchived ? TablerRegular.archive_off : TablerRegular.archive,
        title: isArchived ? loc.sessionListUnarchive : loc.sessionListArchive,
        subtitle: null,
        isSelected: false,
        onTap: () => isArchived
            ? _unarchiveSession(context: context, cubit: cubit, sessionId: session.id)
            : _showArchiveSheet(context: context, cubit: cubit, session: session),
      ),
      // Delete is the only entry here that destroys work the user cannot get
      // back — archiving is reversible — so it is set apart and tinted.
      const PregoMenuDivider(),
      PregoMenuItem(
        leadingIcon: TablerRegular.trash,
        title: loc.sessionListDelete,
        subtitle: null,
        isSelected: false,
        isDestructive: true,
        onTap: () => _showDeleteSheet(context: context, cubit: cubit, session: session),
      ),
    ];
  }

  /// Archives — or unarchives — [session], from the row's trailing swipe pill
  /// or its full-swipe commit.
  void handleSessionArchive({required BuildContext context, required Session session}) {
    final cubit = context.read<SessionListCubit>();
    if (session.time?.archived != null) {
      _unarchiveSession(context: context, cubit: cubit, sessionId: session.id);
    } else {
      _showArchiveSheet(context: context, cubit: cubit, session: session);
    }
  }

  /// Deletes [session] behind the same confirmation flow as the menu entry,
  /// from the row's trailing swipe pill.
  void handleSessionDelete({required BuildContext context, required Session session}) {
    _showDeleteSheet(context: context, cubit: context.read<SessionListCubit>(), session: session);
  }

  /// Flips [session]'s read state, from the row's leading swipe.
  void handleSessionToggleUnread({required BuildContext context, required Session session}) {
    final cubit = context.read<SessionListCubit>();
    unawaited(cubit.markSessionSeen(sessionId: session.id, read: _isUnseen(cubit: cubit, session: session)));
  }

  /// The row's effective unseen state: the cubit's live tracking when loaded,
  /// else what the session payload said.
  bool _isUnseen({required SessionListCubit cubit, required Session session}) {
    final state = cubit.state;
    return state is SessionListLoaded ? (state.unseenBySessionId[session.id] ?? session.unseen) : session.unseen;
  }
}
