import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/injection.dart";

/// Gives the rating sheet's private step a recorder of its own. Feedback
/// belongs to no project, and closing the step discards any recording or
/// transcription still running.
class const FeedbackVoiceInputScope({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final service = getIt<VoiceTranscriptionService>();
        return VoiceInputCubit(service: service, session: service.createSession(projectId: null));
      },
      child: child,
    );
  }
}
