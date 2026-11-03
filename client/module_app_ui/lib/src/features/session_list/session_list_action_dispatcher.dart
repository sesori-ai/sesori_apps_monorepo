import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
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

  /// A pointer surface: a centred dialog that asks before the delete starts.
  alert,
}

/// Which read action a session menu offers.
sealed class const SessionReadMenuEntry();

/// A list row: flips the row's read state, [unseen].
final class const SessionReadMenuToggle({required final bool unseen}) extends SessionReadMenuEntry;

/// An open session page: always Mark as unread. The page is marked seen
/// asynchronously, so a toggle could read "unseen" and mark it read instead.
final class const SessionReadMenuMarkUnread() extends SessionReadMenuEntry;

/// The surface offers Mark unread on its own, as the desktop session page
/// does with its shortcut.
final class const SessionReadMenuNone() extends SessionReadMenuEntry;

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
  /// [isRunning] is whether the session works right now, so archive asks first.
  List<PregoMenuEntry> sessionMenuEntries({
    required BuildContext context,
    required SessionActionsCubit actions,
    required Session session,
    required bool isRunning,
    required SessionReadMenuEntry readEntry,
  }) {
    final loc = context.loc;
    final isArchived = session.time?.archived != null;
    final markRead = readEntry is SessionReadMenuToggle && readEntry.unseen;

    return [
      if (!isArchived)
        PregoMenuItem(
          leadingIcon: TablerRegular.pencil,
          title: loc.rename,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => unawaited(showRenameSessionDialog(context: context, session: session, actions: actions)),
        ),
      if (readEntry is! SessionReadMenuNone)
        PregoMenuItem(
          leadingIcon: markRead ? TablerRegular.mail_opened : TablerRegular.mail,
          title: markRead ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _setRead(context: context, actions: actions, session: session, read: markRead),
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
          onTap: () => _archive(context: context, session: session, isRunning: isRunning),
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
        onTap: () => _delete(context: context, actions: actions, session: session),
      ),
    ];
  }

  /// Archives [session], from the row's trailing swipe pill or its full-swipe
  /// commit. [context] and [isRunning] are as for [sessionMenuEntries].
  void handleSessionArchive({
    required BuildContext context,
    required Session session,
    required bool isRunning,
  }) => _archive(context: context, session: session, isRunning: isRunning);

  /// Deletes [session] behind the same confirmation flow as the menu entry,
  /// from the row's trailing swipe pill.
  void handleSessionDelete({
    required BuildContext context,
    required SessionActionsCubit actions,
    required Session session,
  }) => _delete(context: context, actions: actions, session: session);

  /// Archiving always asks the bridge to remove a dedicated worktree. The user
  /// never chooses otherwise: the bridge's cleanup refusal is what protects
  /// unfinished work.
  void _archive({required BuildContext context, required Session session, required bool isRunning}) {
    unawaited(() async {
      if (isRunning && !await _confirmArchiveRunning(context: context, session: session)) return;
      if (!context.mounted) return;
      context.read<PendingSessionArchiveCubit>().archive(session: session, deleteWorktree: session.hasWorktree);
      onSessionArchived?.call(context: context, sessionId: session.id);
    }());
  }

  void _delete({required BuildContext context, required SessionActionsCubit actions, required Session session}) {
    final deletesFolder = _isNoProject(context: context, session: session);
    switch (deleteConfirmation) {
      case SessionDeleteConfirmation.sheet:
        _showDeleteSheet(
          context: context,
          actions: actions,
          session: session,
          deletesFolder: deletesFolder,
          onSessionDeleted: onSessionDeleted,
        );
      case SessionDeleteConfirmation.alert:
        unawaited(() async {
          if (!await _confirmDelete(context: context, session: session, deletesFolder: deletesFolder) ||
              !context.mounted) {
            return;
          }
          await _deleteSession(
            context: context,
            actions: actions,
            sessionId: session.id,
            deleteWorktree: session.hasWorktree,
            deleteSessionFolder: deletesFolder,
            onSessionDeleted: onSessionDeleted,
          );
        }());
    }
  }

  /// Whether [session] is a "No project" one, in its own folder that deleting
  /// the session removes with its files.
  bool _isNoProject({required BuildContext context, required Session session}) =>
      context.read<ProjectListCubit>().state.kindOf(projectId: session.projectID) == ProjectKind.scratch;

  /// Flips [session]'s read state, [unseen], from the row's leading swipe.
  void handleSessionToggleUnread({
    required BuildContext context,
    required SessionActionsCubit actions,
    required Session session,
    required bool unseen,
  }) => _setRead(context: context, actions: actions, session: session, read: unseen);

  /// Marks [session] unread whatever the local state says. An open session is
  /// marked seen asynchronously, so local state can still read "unseen" and a
  /// toggle would mark it read instead.
  void handleSessionMarkUnread({
    required BuildContext context,
    required SessionActionsCubit actions,
    required Session session,
  }) => _setRead(context: context, actions: actions, session: session, read: false);

  void _setRead({
    required BuildContext context,
    required SessionActionsCubit actions,
    required Session session,
    required bool read,
  }) {
    unawaited(actions.markSessionSeen(projectId: session.projectID, sessionId: session.id, read: read));
    if (!read) onSessionMarkedUnread?.call(context: context, session: session);
  }
}
