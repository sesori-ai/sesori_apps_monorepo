import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/injection.dart";

/// Injects mobile-only composer policy and platform capabilities.
class const MobileComposerPresentationScope({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inputMode = context.watch<ChatInputModeCubit>().state;
    return KeyboardVisibilityBuilder(
      builder: (context, isKeyboardVisible) => ComposerPresentationScope(
        voiceSupport: ComposerVoiceSupport.supported,
        inputMode: inputMode,
        isKeyboardVisible: isKeyboardVisible,
        sendKeyPolicy: ComposerSendKeyPolicy.modifierEnterSends,
        attachmentDispatcher: getIt.get<ComposerAttachmentDispatcher>,
        imageClipboard: getIt.get<ImageClipboard>,
        child: child,
      ),
    );
  }
}
