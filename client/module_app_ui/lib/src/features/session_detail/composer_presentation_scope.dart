import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Whether the product shell supplies a real voice-capture implementation for
/// this composer.
// WORKAROUND: dart_style 3.1.12 crashes on empty enhanced enum constructors.
// ignore: use_primary_constructors
enum ComposerVoiceSupport { supported, unsupported }

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
      attachmentDispatcher != oldWidget.attachmentDispatcher ||
      imageClipboard != oldWidget.imageClipboard;
}
