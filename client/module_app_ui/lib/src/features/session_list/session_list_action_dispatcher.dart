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

class const SessionListActionDispatcher({required final SessionDeletedRouteHandler? onSessionDeleted}) {
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
        onTap: () => handleSessionToggleUnread(context: context, session: session),
      ),
      // Archiving is permanent, so an already-archived row has no archive
      // action left to offer.
      if (!isArchived)
        PregoMenuItem(
          leadingIcon: TablerRegular.archive,
          title: loc.sessionListArchive,
          subtitle: null,
          isSelected: false,
          onTap: () => handleSessionArchive(context: context, session: session),
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
        isDestructive: true,
        onTap: () => handleSessionDelete(context: context, session: session),
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
    unawaited(
      cubit.markSessionSeen(
        sessionId: session.id,
        read: _isUnseen(cubit: cubit, session: session),
      ),
    );
  }

  /// The row's effective unseen state: the cubit's live tracking when loaded,
  /// else what the session payload said.
  bool _isUnseen({required SessionListCubit cubit, required Session session}) {
    final state = cubit.state;
    return state is SessionListLoaded ? state.isSessionUnseen(session: session) : session.unseen;
  }
}
