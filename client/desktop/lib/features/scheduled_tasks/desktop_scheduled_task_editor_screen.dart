import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";
import "../../core/widgets/desktop_pane_drop_target.dart";
import "../../core/widgets/desktop_transcript_width.dart";

/// Desktop composition for the New task page, or the same page editing
/// [taskId].
class const DesktopScheduledTaskEditorScreen({
  super.key,
  required final String? taskId,
  required final VoidCallback onBack,
  required final VoidCallback onSaved,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DesktopPaneDropTarget(
    child: ScheduledTaskEditorView(
      createCubit: () => createScheduledTaskEditorCubit(locator: getIt, taskId: taskId),
      createComposerCubit: ({required purpose}) => createNewSessionCubit(locator: getIt, purpose: purpose),
      onBack: onBack,
      onSaved: onSaved,
      onOpenHarnessSettings: onOpenHarnessSettings,
      composerScopeBuilder: ({required projectId, required child}) => DesktopComposerPresentationScope(
        child: DesktopVoiceInputScope(projectId: projectId, child: child),
      ),
      // The desktop root owns its single connection banner.
      banner: null,
      pageChrome: ({required title}) => NewSessionPageChrome(
        maxContentWidth: desktopComposerWidth,
        transcriptWidth: desktopTranscriptWidth,
        topBar: DesktopPageToolbar(
          breadcrumb: null,
          status: null,
          title: title,
          titleDetail: null,
          subtitle: null,
          keptSuffix: null,
          actions: const [],
        ),
        backgroundColor: null,
      ),
    ),
  );
}
