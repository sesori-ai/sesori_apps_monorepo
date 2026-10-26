import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";
import "../../core/widgets/desktop_transcript_width.dart";

/// Desktop composition boundary for session creation.
class const DesktopNewSessionScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,

  /// Replaces this page with the chosen project's. The route keys this screen
  /// by project, so the switch builds a fresh cubit for that project.
  required final NewSessionProjectSelected onProjectSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => createNewSessionCubit(
        locator: getIt,
        projectId: projectId,
        projectName: projectName,
        projectKind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
      ),
      child: DesktopNewSessionView(
        projectId: projectId,
        projectName: projectName,
        onBack: onBack,
        onOpenHarnessSettings: onOpenHarnessSettings,
        onSessionCreated: onSessionCreated,
        onProjectSelected: onProjectSelected,
      ),
    );
  }
}

@visibleForTesting
class const DesktopNewSessionView({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
  required final NewSessionProjectSelected onProjectSelected,
}) extends StatelessWidget {
  static const double maxContentWidth = 760;

  @override
  Widget build(BuildContext context) {
    return NewSessionView(
      projectId: projectId,
      projectName: projectName,
      onProjectSelected: onProjectSelected,
      onBack: onBack,
      onOpenHarnessSettings: onOpenHarnessSettings,
      onSessionCreated: onSessionCreated,
      composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(
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
    );
  }
}
