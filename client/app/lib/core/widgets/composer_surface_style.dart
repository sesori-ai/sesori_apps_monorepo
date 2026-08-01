import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

PregoComposerSurfaceStyle resolveInitialComposerSurfaceStyle({
  required ChatInputMode inputMode,
  required ComposerDraft draft,
  required CommandInfo? stagedCommand,
}) {
  if (inputMode == ChatInputMode.textFirst || draft.text.trim().isNotEmpty || stagedCommand != null) {
    return PregoComposerSurfaceStyle.emphasized;
  }
  return PregoComposerSurfaceStyle.subtle;
}
