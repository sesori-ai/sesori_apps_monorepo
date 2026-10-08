import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/injection.dart";

/// Injects desktop composer policy, concrete platform capabilities and the
/// composer's voice input for [projectId].
class const DesktopComposerPresentationScope({
  super.key,
  required final String projectId,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final service = getIt<VoiceTranscriptionService>();
        return VoiceInputCubit(service: service, session: service.createSession(projectId: projectId));
      },
      child: ComposerPresentationScope(
        voiceSupport: ComposerVoiceSupport.supported,
        // Desktop leads with the text field; the mic is an extra button that
        // records on click (see ComposerPresentation.pointer).
        inputMode: ChatInputMode.textFirst,
        isKeyboardVisible: false,
        sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
        presentation: ComposerPresentation.pointer,
        attachmentDispatcher: getIt.get<ComposerAttachmentDispatcher>,
        imageClipboard: getIt.get<ImageClipboard>,
        child: child,
      ),
    );
  }
}
