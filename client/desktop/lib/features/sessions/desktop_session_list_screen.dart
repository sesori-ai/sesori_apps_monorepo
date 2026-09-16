import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Owns the full inventory only while the all-sessions page is mounted.
class const DesktopSessionListCubitProvider({
  super.key,
  required final String projectId,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createSessionListCubit(
        mode: const SessionListMode.view(filter: SessionListFilter.active),
        locator: getIt,
        projectId: projectId,
      ),
      child: child,
    );
  }
}

/// Full main-pane composition for the shared session inventory.
class const DesktopSessionListScreen({
  super.key,
  required final String? projectName,
  required final SessionOpenedCallback onSessionTap,
  required final VoidCallback onNewSession,
  required final SessionListActionDispatcher actionDispatcher,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionListScaffold(
      onOpenArchived: () => context.read<SessionListCubit>().toggleArchived(),
      projectName: projectName,
      onSessionTap: onSessionTap,
      actionDispatcher: actionDispatcher,
      archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
      onNewSession: onNewSession,
      onBack: null,
      connectionBanner: null,
    );
  }
}
