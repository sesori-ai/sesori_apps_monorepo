import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The fade behind the floating bottom controls, so the transcript dissolves
/// as it scrolls past them: the same scrim the glass top navigation bar uses,
/// mirrored to the bottom edge. It is opaque where the controls sit and clear
/// where content emerges above them; the controls keep their own surfaces.
BoxDecoration composerScrimDecoration({required PregoDesignSystem prego}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.center,
      end: Alignment.topCenter,
      colors: [
        prego.colors.bgSurface1.withValues(alpha: 0.98),
        prego.colors.bgSurface1.withValues(alpha: 0.88),
        prego.colors.bgSurface1.withValues(alpha: 0),
      ],
      stops: const [0, 0.8, 1.0],
    ),
  );
}

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
