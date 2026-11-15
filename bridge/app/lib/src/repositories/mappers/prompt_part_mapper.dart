import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/deliverable_prompt_part.dart";

extension DeliverablePromptPartToPlugin on DeliverablePromptPart {
  PluginPromptPart toPlugin() => switch (this) {
    DeliverablePromptPartText(:final text) => PluginPromptPart.text(text: text),
    DeliverablePromptPartFileUrl(:final mime, :final url, :final filename) => PluginPromptPart.fileUrl(
      mime: mime,
      url: url,
      filename: filename,
    ),
    DeliverablePromptPartFileData(:final mime, :final base64, :final filename) => PluginPromptPart.fileData(
      mime: mime,
      base64: base64,
      filename: filename,
    ),
  };
}
