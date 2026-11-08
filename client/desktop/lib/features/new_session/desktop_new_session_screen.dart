import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";
import "../../core/widgets/desktop_pane_drop_target.dart";
import "../../core/widgets/desktop_transcript_width.dart";

/// Desktop composition boundary for session creation.
class const DesktopNewSessionScreen({
  super.key,

  /// The project the page opens in. Choosing another project in the page
  /// moves its composer there, keeping the route.
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => createNewSessionCubit(
        locator: getIt,
        project: NewSessionProject(
          id: projectId,
          name: projectName,
          kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
        ),
      ),
      child: DesktopNewSessionView(
        onBack: onBack,
        onOpenHarnessSettings: onOpenHarnessSettings,
        onSessionCreated: onSessionCreated,
      ),
    );
  }
}

@visibleForTesting
class const DesktopNewSessionView({
  super.key,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
}) extends StatelessWidget {
  static const double maxContentWidth = 760;

  @override
  Widget build(BuildContext context) {
    return DesktopPaneDropTarget(
      child: NewSessionView(
        onProjectSelected: ({required projectId, required projectName}) =>
            context.read<NewSessionCubit>().selectProject(
              project: NewSessionProject(
                id: projectId,
                name: projectName,
                kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
              ),
            ),
        onBack: onBack,
        onOpenHarnessSettings: onOpenHarnessSettings,
        onSessionCreated: onSessionCreated,
        composerScopeBuilder: ({required projectId, required child}) => DesktopComposerPresentationScope(
          child: DesktopVoiceInputScope(projectId: projectId, child: child),
        ),
        // The desktop root owns its single connection banner.
        banner: null,
        pageChrome: NewSessionPageChrome(
          maxContentWidth: maxContentWidth,
          transcriptWidth: desktopTranscriptWidth,
          // The header's project picker names the project.
          topBar: DesktopPageToolbar(
            breadcrumb: null,
            status: null,
            title: context.loc.sessionListNewSession,
            subtitle: null,
            actions: const [],
          ),
          // A page of its own, so opaque as it fades in over the one below.
          backgroundColor: null,
        ),
      ),
    );
  }
}
