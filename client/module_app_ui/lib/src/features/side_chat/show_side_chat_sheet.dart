import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../session_detail/session_detail_presentation_scope.dart";
import "side_chat_view.dart";

/// Shows a session's side chats in a two-height sheet over its page, which
/// stays mounted underneath and keeps streaming. [createCubit] makes the
/// sheet's cubit, which lives as long as the sheet.
///
/// [context] is under the session page's [SessionDetailPresentationScope],
/// which the answers' links use.
void showSideChatSheet({
  required BuildContext context,
  required String pluginId,
  required SideChatCubit Function() createCubit,
}) {
  final scope = SessionDetailPresentationScope.read(context);
  // ignore: no_slop_linter/avoid_navigator_of, the sheet is a transient route over the session page
  final navigator = Navigator.of(context);
  unawaited(
    showPregoDetentSheet<void>(
      context: context,
      builder: (context, scrollController) => scope.around(
        openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {
          navigator.pop();
          scope.openSession(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly);
        },
        child: BlocProvider(
          create: (_) => createCubit(),
          child: SideChatView(
            scrollController: scrollController,
            harnessName: PregoBrandLogo.displayNameFor(pluginId),
            onClose: navigator.pop,
          ),
        ),
      ),
    ),
  );
}
