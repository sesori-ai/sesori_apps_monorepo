import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/injection.dart";

/// Injects desktop composer policy and concrete platform capabilities.
class const DesktopComposerPresentationScope({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ComposerPresentationScope(
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
    );
  }
}

/// Provides the composer's voice input for [projectId].
///
/// Wrap only the composer itself, as the phone does: when the composer leaves
/// the tree (a blocked or read-only session), the recording closes with it.
class const DesktopVoiceInputScope({
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
      child: child,
    );
  }
}
