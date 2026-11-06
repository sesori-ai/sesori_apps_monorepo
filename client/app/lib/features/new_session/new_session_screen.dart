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

  /// The project the page opens in; null asks for a project first. Choosing
  /// another project in the page moves its composer there, keeping the route.
  required final String? projectId,
  required final String? projectName,

  /// How the page opened, so it still leaves the way it came in.
  required final NewSessionEntry entry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final projectId = this.projectId;
    if (projectId == null) {
      return NewSessionProjectPrompt(
        onProjectSelected: ({required projectId, required projectName}) {
          context.replaceRoute(AppRoute.newSession(projectId: projectId, projectName: projectName, entry: entry));
        },
        onBack: context.pop,
        banner: ConnectionBanner.maybeFor(context),
        opensPicker: true,
        topBar: null,
      );
    }
    return BlocProvider(
      create: (context) => createNewSessionCubit(
        locator: getIt,
        project: NewSessionProject(
          id: projectId,
          name: projectName,
          kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
        ),
      ),
      child: Builder(builder: (context) => _build(context: context)),
    );
  }

  Widget _build({required BuildContext context}) {
    return NewSessionView(
      onProjectSelected: ({required projectId, required projectName}) => context.read<NewSessionCubit>().selectProject(
        project: NewSessionProject(
          id: projectId,
          name: projectName,
          kind: context.read<ProjectListCubit>().state.kindOf(projectId: projectId),
        ),
      ),
      onBack: context.pop,
      onOpenHarnessSettings: () => context.pushRoute(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
      ),
      onSessionCreated: ({required session, required project}) => context.replaceRoute(
        AppRoute.sessionDetail(
          projectId: project.id,
          projectName: project.name,
          sessionId: session.id,
          sessionTitle: session.title,
          readOnly: false,
          // The session screen takes over the first message in place.
          fromLaunch: true,
        ),
      ),
      composerScopeBuilder: ({required projectId, required child}) {
        return BlocProvider(
          create: (_) {
            final service = getIt<VoiceTranscriptionService>();
            return VoiceInputCubit(
              service: service,
              session: service.createSession(projectId: projectId, allowLive: true),
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
