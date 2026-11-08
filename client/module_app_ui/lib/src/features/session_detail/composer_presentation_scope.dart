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

/// How the product shell lays the composer out.
enum ComposerPresentation() {
  /// Touch-sized: selectors share the strip's width, `+` and `/` sit behind
  /// the options pill, and a full-screen editor is offered for long prompts.
  touch,

  /// Pointer-sized: selectors hug their labels at the leading edge, `+` and
  /// `/` are always visible, the box itself grows for long prompts, and the
  /// mic records on click until a wide Send, Enter, the pencil, Shift+Enter, the
  /// X or Escape ends it.
  pointer,
}

/// What the shell's attach action picks.
enum ComposerAttachKind() {
  /// A gallery image.
  images,

  /// Any files: images are staged, the rest are routed like a drop.
  files,
}

typedef ComposerCapabilityProvider<T> = T Function();

/// Product-owned platform and presentation capabilities for shared composers.
///
/// Mobile supplies live keyboard visibility and its chosen input mode. Desktop
/// always leads with text. Both products supply voice capture and provide real
/// image picking and clipboard implementations lazily.
class const ComposerPresentationScope({
  super.key,
  required final ComposerVoiceSupport voiceSupport,
  required final ChatInputMode inputMode,
  required final bool isKeyboardVisible,
  required final ComposerSendKeyPolicy sendKeyPolicy,
  required final ComposerPresentation presentation,
  required final ComposerCapabilityProvider<ComposerAttachmentDispatcher> attachmentDispatcher,
  required final ComposerCapabilityProvider<ImageClipboard> imageClipboard,

  /// The files copied in the file manager, which a paste adds like a drop, or
  /// null where the shell pastes no files.
  required final ComposerCapabilityProvider<FileClipboard>? fileClipboard,

  /// Paths dropped on the pane around this composer, or null where the shell
  /// takes no drops.
  required final Stream<List<String>>? droppedPaths,
  required final ComposerAttachKind attachKind,
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
      presentation != oldWidget.presentation ||
      attachmentDispatcher != oldWidget.attachmentDispatcher ||
      imageClipboard != oldWidget.imageClipboard ||
      fileClipboard != oldWidget.fileClipboard ||
      droppedPaths != oldWidget.droppedPaths ||
      attachKind != oldWidget.attachKind;
}
