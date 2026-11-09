import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_prompt_part.freezed.dart";

part "plugin_prompt_part.g.dart";

@freezed
sealed class PluginPromptPart with _$PluginPromptPart {
  const factory text({required String text}) = PluginPromptPartText;
  const factory filePath({required String mime, required String path, required String? filename}) =
      PluginPromptPartFilePath;
  const factory fileUrl({required String mime, required String url, required String? filename}) =
      PluginPromptPartFileUrl;
  const factory fileData({required String mime, required String base64, required String? filename}) =
      PluginPromptPartFileData;
}

/// Joins each run of adjacent text parts into one, a blank line apart, as the
/// bridge joins a prompt's visible texts. Plugins whose agent keeps or replays
/// one text item per part use it so a saved file's note stays its own
/// paragraph instead of hiding or gluing onto the user's text. A run of several
/// drops its blank texts; a lone part is kept as it is.
List<PluginPromptPart> joinAdjacentPromptTextParts({required List<PluginPromptPart> parts}) {
  final joined = <PluginPromptPart>[];
  final run = <PluginPromptPartText>[];
  void flushRun() {
    if (run.length == 1) {
      joined.add(run.single);
    } else if (run.isNotEmpty) {
      final texts = run.map((part) => part.text).where((text) => text.trim().isNotEmpty);
      joined.add(PluginPromptPart.text(text: texts.join("\n\n")));
    }
    run.clear();
  }

  for (final part in parts) {
    if (part is PluginPromptPartText) {
      run.add(part);
      continue;
    }
    flushRun();
    joined.add(part);
  }
  flushRun();
  return joined;
}
