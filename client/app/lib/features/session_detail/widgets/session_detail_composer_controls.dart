import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../core/di/injection.dart";
import "../../../core/widgets/mobile_composer_presentation_scope.dart";

/// Mobile composition for the shared session composer.
class const MobileSessionDetailComposerControls({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final SessionDetailLoaded state,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = getIt<VoiceTranscriptionService>();
    return BlocProvider(
      create: (_) => VoiceInputCubit(
        service: service,
        session: service.createSession(projectId: projectId),
      ),
      child: MobileComposerPresentationScope(
        child: SessionDetailComposerControls(
          projectId: projectId,
          sessionId: sessionId,
          state: state,
        ),
      ),
    );
  }
}
