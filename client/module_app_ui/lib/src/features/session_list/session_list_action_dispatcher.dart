import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "rename_session_dialog.dart";

part "session_cleanup_alerts.dart";
part "session_cleanup_dialogs.dart";
part "session_force_dialog.dart";
part "session_list_actions.dart";

typedef SessionDeletedRouteHandler = void Function({
  required BuildContext context,
  required String sessionId,
});

typedef SessionMarkedUnreadHandler = void Function({
  required BuildContext context,
  required Session session,
});

/// How a surface asks before deleting. Archive never asks first, except for a
/// running session: it happens at once behind the shell's Undo window.
enum SessionDeleteConfirmation() {
  /// The phone: a bottom sheet.
  sheet,

  /// A pointer surface: a compact centred alert.
  alert,
}

/// Which read action a session menu offers.
enum SessionReadMenuEntry() {
  /// A list row: flips the row's read state.
  toggle,

  /// An open session page: always Mark as unread. The page is marked seen
  /// asynchronously, so a toggle could read "unseen" and mark it read instead.
  markUnread,

  /// The surface offers Mark unread on its own, as the desktop session page
  /// does with its shortcut.
  none,
}

void _showRetainedActionDialog({
  required SessionListCubit cubit,
  required Future<void> Function() show,
}) {
  final release = cubit.retainActionScope();
  unawaited(show().whenComplete(release));
}

class const SessionListActionDispatcher({
  required final SessionDeleteConfirmation deleteConfirmation,

  /// Told once an archive enters its Undo window, so an open page can close.
  required final SessionDeletedRouteHandler? onSessionArchived,
  required final SessionDeletedRouteHandler? onSessionDeleted,

  /// Told when the user marks a session unread, never when they mark it read.
  required final SessionMarkedUnreadHandler? onSessionMarkedUnread,
}) {
  /// The long-press actions for [session], rendered by [SessionTile] in a
  /// [PregoAnchorMenu] anchored to the row.
  ///
  /// [context] must belong to the stable list/sidebar owner rather than the
  /// row: archive/delete can remove that row before their follow-up UI runs.
  /// [cubit] may be scoped more narrowly and is retained while confirmation
  /// UI is open and while the resulting operation settles.
  List<PregoMenuEntry> sessionMenuEntries({
    required BuildContext context,
    required SessionListCubit cubit,
    required Session session,
    required SessionReadMenuEntry readEntry,
  }) {
    final loc = context.loc;
    final isArchived = session.time?.archived != null;
    final markRead = readEntry == SessionReadMenuEntry.toggle && _isUnseen(cubit: cubit, session: session);

    return [
      if (!isArchived)
        PregoMenuItem(
          leadingIcon: TablerRegular.pencil,
          title: loc.rename,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _showRetainedActionDialog(
            cubit: cubit,
            show: () => showRenameSessionDialog(context: context, session: session, cubit: cubit),
          ),
        ),
      if (readEntry != SessionReadMenuEntry.none)
        PregoMenuItem(
          leadingIcon: markRead ? TablerRegular.mail_opened : TablerRegular.mail,
          title: markRead ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _setRead(context: context, cubit: cubit, session: session, read: markRead),
        ),
      // Archiving is permanent, so an already-archived row has no archive
      // action left to offer.
      if (!isArchived)
        PregoMenuItem(
          leadingIcon: TablerRegular.archive,
          title: loc.sessionListArchive,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _archive(context: context, cubit: cubit, session: session, deleteWorktree: true),
        ),
      if (!isArchived && session.hasWorktree)
        PregoMenuItem(
          leadingIcon: TablerRegular.archive,
          title: loc.sessionListArchiveKeepWorktree,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _archive(context: context, cubit: cubit, session: session, deleteWorktree: false),
        ),
      // Delete is the only entry here that also destroys the work itself —
      // archiving is permanent but keeps the session readable — so it is set
      // apart and tinted.
      const PregoMenuDivider(),
      PregoMenuItem(
        leadingIcon: TablerRegular.trash,
        title: loc.sessionListDelete,
        subtitle: null,
        isSelected: false,
        shortcutLabel: null,
        isDestructive: true,
        onTap: () => _delete(context: context, cubit: cubit, session: session),
      ),
    ];
  }

  /// Archives [session], from the row's trailing swipe pill or its full-swipe
  /// commit.
  void handleSessionArchive({required BuildContext context, required Session session}) {
    _archive(context: context, cubit: context.read<SessionListCubit>(), session: session, deleteWorktree: true);
  }

  /// Deletes [session] behind the same confirmation flow as the menu entry,
  /// from the row's trailing swipe pill.
  void handleSessionDelete({required BuildContext context, required Session session}) {
    _delete(context: context, cubit: context.read<SessionListCubit>(), session: session);
  }

  void _archive({
    required BuildContext context,
    required SessionListCubit cubit,
    required Session session,
    required bool deleteWorktree,
  }) {
    final state = cubit.state;
    final isRunning = state is SessionListLoaded && state.isSessionRunning(session: session);
    unawaited(() async {
      if (isRunning && !await _confirmArchiveRunning(context: context, session: session)) return;
      if (!context.mounted) return;
      context.read<PendingSessionArchiveCubit>().archive(
        session: session,
        deleteWorktree: deleteWorktree && session.hasWorktree,
      );
      onSessionArchived?.call(context: context, sessionId: session.id);
    }());
  }

  void _delete({required BuildContext context, required SessionListCubit cubit, required Session session}) {
    switch (deleteConfirmation) {
      case SessionDeleteConfirmation.sheet:
        _showDeleteSheet(context: context, cubit: cubit, session: session, onSessionDeleted: onSessionDeleted);
      case SessionDeleteConfirmation.alert:
        _showRetainedActionDialog(
          cubit: cubit,
          show: () async {
            final deleteWorktree = await _confirmDelete(context: context, session: session);
            if (deleteWorktree == null || !context.mounted) return;
            await _deleteSession(
              context: context,
              cubit: cubit,
              sessionId: session.id,
              deleteWorktree: deleteWorktree,
              onSessionDeleted: onSessionDeleted,
            );
          },
        );
    }
  }

  /// Flips [session]'s read state, from the row's leading swipe.
  void handleSessionToggleUnread({required BuildContext context, required Session session}) {
    final cubit = context.read<SessionListCubit>();
    _setRead(
      context: context,
      cubit: cubit,
      session: session,
      read: _isUnseen(cubit: cubit, session: session),
    );
  }

  /// Marks [session] unread whatever the local state says. An open session is
  /// marked seen asynchronously, so local state can still read "unseen" and a
  /// toggle would mark it read instead.
  void handleSessionMarkUnread({
    required BuildContext context,
    required SessionListCubit cubit,
    required Session session,
  }) => _setRead(context: context, cubit: cubit, session: session, read: false);

  void _setRead({
    required BuildContext context,
    required SessionListCubit cubit,
    required Session session,
    required bool read,
  }) {
    unawaited(cubit.markSessionSeen(sessionId: session.id, read: read));
    if (!read) onSessionMarkedUnread?.call(context: context, session: session);
  }

  /// The row's effective unseen state: the cubit's live tracking when loaded,
  /// else what the session payload said.
  bool _isUnseen({required SessionListCubit cubit, required Session session}) {
    final state = cubit.state;
    return state is SessionListLoaded ? state.isSessionUnseen(session: session) : session.unseen;
  }
}
