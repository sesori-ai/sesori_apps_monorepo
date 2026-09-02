import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The composer's three visual layouts and their shared surface treatment.
enum ComposerSurfaceLayout({required final PregoComposerSurfaceStyle surfaceStyle}) {
  holdToTalk(surfaceStyle: PregoComposerSurfaceStyle.subtle),
  compact(surfaceStyle: PregoComposerSurfaceStyle.emphasized),
  typing(surfaceStyle: PregoComposerSurfaceStyle.emphasized),
}

ComposerSurfaceLayout resolveComposerSurfaceLayout({
  required ChatInputMode inputMode,
  required bool showsTypingLayout,
}) {
  if (showsTypingLayout) return ComposerSurfaceLayout.typing;
  return switch (inputMode) {
    ChatInputMode.voiceFirst => ComposerSurfaceLayout.holdToTalk,
    ChatInputMode.textFirst => ComposerSurfaceLayout.compact,
  };
}

PregoComposerSurfaceStyle resolveInitialComposerSurfaceStyle({
  required ChatInputMode inputMode,
  required ComposerDraft draft,
  required CommandInfo? stagedCommand,
}) {
  return resolveComposerSurfaceLayout(
    inputMode: inputMode,
    showsTypingLayout: draft.text.trim().isNotEmpty || stagedCommand != null,
  ).surfaceStyle;
}
