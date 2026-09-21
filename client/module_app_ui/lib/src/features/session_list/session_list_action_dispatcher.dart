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

void _showRetainedActionDialog({
  required SessionListCubit cubit,
  required Future<void> Function() show,
}) {
  final release = cubit.retainActionScope();
  unawaited(show().whenComplete(release));
}

class const SessionListActionDispatcher({
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

    /// False where the surface offers Mark unread on its own, as the session
    /// page's toolbar does.
    required bool includeReadToggle,
  }) {
    final loc = context.loc;
    final isArchived = session.time?.archived != null;
    final isUnseen = _isUnseen(cubit: cubit, session: session);

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
      if (includeReadToggle)
        PregoMenuItem(
          leadingIcon: isUnseen ? TablerRegular.mail_opened : TablerRegular.mail,
          title: isUnseen ? loc.sessionListMarkRead : loc.sessionListMarkUnread,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          onTap: () => _setRead(context: context, cubit: cubit, session: session, read: isUnseen),
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
          onTap: () => _showArchiveSheet(context: context, cubit: cubit, session: session),
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
        onTap: () => _showDeleteSheet(
          context: context,
          cubit: cubit,
          session: session,
          onSessionDeleted: onSessionDeleted,
        ),
      ),
    ];
  }

  /// Archives [session], from the row's trailing swipe pill or its full-swipe
  /// commit.
  void handleSessionArchive({required BuildContext context, required Session session}) {
    _showArchiveSheet(context: context, cubit: context.read<SessionListCubit>(), session: session);
  }

  /// Deletes [session] behind the same confirmation flow as the menu entry,
  /// from the row's trailing swipe pill.
  void handleSessionDelete({required BuildContext context, required Session session}) {
    _showDeleteSheet(
      context: context,
      cubit: context.read<SessionListCubit>(),
      session: session,
      onSessionDeleted: onSessionDeleted,
    );
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
