import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";

/// Desktop composition boundary for session creation.
class const DesktopNewSessionScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createNewSessionCubit(locator: getIt, projectId: projectId),
      child: DesktopNewSessionView(
        projectId: projectId,
        projectName: projectName,
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
  required final String projectId,
  required final String? projectName,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NewSessionView(
      projectId: projectId,
      onBack: onBack,
      onOpenHarnessSettings: onOpenHarnessSettings,
      onSessionCreated: onSessionCreated,
      composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(child: child),
      subtitle: switch (projectName) {
        final projectName? => Text(projectName),
        null => null,
      },
      // The desktop root owns its single connection banner.
      banner: null,
    );
  }
}
