import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PromptPartToPlugin on PromptPart {
  PluginPromptPart toPlugin() => switch (this) {
    PromptPartText(:final text) => PluginPromptPart.text(text: text),
    PromptPartFilePath(:final mime, :final path, :final filename) => PluginPromptPart.filePath(
      mime: mime,
      path: path,
      filename: filename,
    ),
    PromptPartFileUrl(:final mime, :final url, :final filename) => PluginPromptPart.fileUrl(
      mime: mime,
      url: url,
      filename: filename,
    ),
    PromptPartFileData(:final mime, :final base64, :final filename) => PluginPromptPart.fileData(
      mime: mime,
      base64: base64,
      filename: filename,
    ),
  };
}
