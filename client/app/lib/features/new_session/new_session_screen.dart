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
  required final String projectId,
  required final String? projectName,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSessionCubit(
        connectionService: getIt<ConnectionService>(),
        sessionRepository: getIt<SessionRepository>(),
        newSessionPluginService: getIt<NewSessionPluginService>(),
        newSessionOptionsService: getIt<NewSessionOptionsService>(),
        projectRepository: getIt<ProjectRepository>(),
        selectionTracker: getIt<NewSessionSelectionTracker>(),
        composerDraftRepository: getIt<ComposerDraftRepository>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        projectId: projectId,
      ),
      child: NewSessionView(
        projectId: projectId,
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
        subtitle: buildProjectNavSubtitle(context),
        banner: ConnectionBanner.maybeFor(context),
      ),
    );
  }
}
