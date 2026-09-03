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
      voiceSupport: ComposerVoiceSupport.unsupported,
      // Desktop has no voice-capture implementation in this slice, so a saved
      // mobile voice-first preference must not turn into a dead voice control.
      inputMode: ChatInputMode.textFirst,
      isKeyboardVisible: false,
      attachmentDispatcher: getIt.get<ComposerAttachmentDispatcher>,
      imageClipboard: getIt.get<ImageClipboard>,
      child: child,
    );
  }
}
