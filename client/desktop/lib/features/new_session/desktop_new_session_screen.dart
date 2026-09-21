import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

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
    final projectList = context.watch<ProjectListCubit>().state;
    return BlocProvider(
      create: (_) => createNewSessionCubit(locator: getIt, projectId: projectId),
      child: DesktopNewSessionView(
        projectId: projectId,
        projectName: projectName,
        onBack: onBack,
        onOpenHarnessSettings: onOpenHarnessSettings,
        onSessionCreated: onSessionCreated,
        onProjectSelected: onProjectSelected,
        projects: projectList is ProjectListLoaded ? projectList.projects : const [],
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
  required final List<ProjectSummary> projects,
}) extends StatelessWidget {
  static const double maxContentWidth = 760;

  @override
  Widget build(BuildContext context) {
    return NewSessionView(
      projectId: projectId,
      projectName: projectName,
      projects: projects,
      onProjectSelected: onProjectSelected,
      onBack: onBack,
      onOpenHarnessSettings: onOpenHarnessSettings,
      onSessionCreated: onSessionCreated,
      composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(child: child),
      // The desktop root owns its single connection banner.
      banner: null,
      pageChrome: NewSessionPageChrome(
        maxContentWidth: maxContentWidth,
        topBar: DesktopPageToolbar(
          leading: IconButton(
            key: const Key("desktop-new-session-back"),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(TablerRegular.arrow_left, size: 18),
          ),
          title: context.loc.sessionListNewSession,
          subtitle: null,
          actions: const [],
        ),
      ),
    );
  }
}
