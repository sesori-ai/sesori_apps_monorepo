import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Whether the product shell supplies a real voice-capture implementation for
/// this composer.
enum ComposerVoiceSupport({required final bool isSupported}) {
  supported(isSupported: true),
  unsupported(isSupported: false),
}

/// Product-owned hardware-keyboard policy for a multiline composer.
enum ComposerSendKeyPolicy() {
  /// Enter inserts a newline; Cmd/Ctrl+Enter sends.
  modifierEnterSends,

  /// Enter sends; Shift+Enter inserts a newline.
  enterSends,
}

typedef ComposerCapabilityProvider<T> = T Function();

/// Product-owned platform and presentation capabilities for shared composers.
///
/// Mobile supplies live keyboard visibility and voice capture. Desktop
/// explicitly selects text-first input with voice unsupported. Both products
/// provide real image picking and clipboard implementations lazily.
class const ComposerPresentationScope({
  super.key,
  required final ComposerVoiceSupport voiceSupport,
  required final ChatInputMode inputMode,
  required final bool isKeyboardVisible,
  required final ComposerSendKeyPolicy sendKeyPolicy,
  required final ComposerCapabilityProvider<ComposerAttachmentDispatcher> attachmentDispatcher,
  required final ComposerCapabilityProvider<ImageClipboard> imageClipboard,
  required super.child,
}) extends InheritedWidget {
  static ComposerPresentationScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ComposerPresentationScope>();
    return scope ?? (throw StateError("ComposerPresentationScope was not found in the widget tree"));
  }

  static ComposerPresentationScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ComposerPresentationScope>();
    return scope ?? (throw StateError("ComposerPresentationScope was not found in the widget tree"));
  }

  @override
  bool updateShouldNotify(ComposerPresentationScope oldWidget) =>
      voiceSupport != oldWidget.voiceSupport ||
      inputMode != oldWidget.inputMode ||
      isKeyboardVisible != oldWidget.isKeyboardVisible ||
      sendKeyPolicy != oldWidget.sendKeyPolicy ||
      attachmentDispatcher != oldWidget.attachmentDispatcher ||
      imageClipboard != oldWidget.imageClipboard;
}
