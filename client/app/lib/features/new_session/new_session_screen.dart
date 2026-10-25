import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/mobile_composer_presentation_scope.dart";

class const NewSessionScreen({
  super.key,

  /// Null asks for a project first.
  required final String? projectId,
  required final String? projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final projectId = this.projectId;
    if (projectId == null) {
      return NewSessionProjectPrompt(
        onProjectSelected: ({required projectId, required projectName}) =>
            context.replaceRoute(AppRoute.newSession(projectId: projectId, projectName: projectName)),
        onBack: context.pop,
        banner: ConnectionBanner.maybeFor(context),
        opensPicker: true,
        topBar: null,
      );
    }
    return BlocProvider(
      // Replacing the route keeps its page, so the project keys the provider:
      // another project gets a fresh cubit and never the one that was left.
      key: ValueKey(projectId),
      create: (_) => createNewSessionCubit(locator: getIt, projectId: projectId, projectName: projectName),
      child: Builder(
        builder: (context) => _build(context: context, projectId: projectId),
      ),
    );
  }

  Widget _build({required BuildContext context, required String projectId}) {
    return NewSessionView(
      projectId: projectId,
      projectName: projectName,
      // A different project is a different page: the route builds a fresh
      // cubit for it.
      onProjectSelected: ({required projectId, required projectName}) => context.replaceRoute(
        AppRoute.newSession(projectId: projectId, projectName: projectName),
      ),
      onBack: context.pop,
      onOpenHarnessSettings: () => context.pushRoute(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
      ),
      onSessionCreated: ({required session}) => context.replaceRoute(
        AppRoute.sessionDetail(
          projectId: projectId,
          projectName: projectName,
          sessionId: session.id,
          sessionTitle: session.title,
          readOnly: false,
          // The session screen takes over the first message in place.
          fromLaunch: true,
        ),
      ),
      composerScopeBuilder: ({required child}) {
        return BlocProvider(
          create: (_) {
            final service = getIt<VoiceTranscriptionService>();
            return VoiceInputCubit(
              service: service,
              session: service.createSession(projectId: projectId),
            );
          },
          child: MobileComposerPresentationScope(child: child),
        );
      },
      banner: ConnectionBanner.maybeFor(context),
      pageChrome: null,
    );
  }
}
