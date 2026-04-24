import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class SendPromptBody {
  final List<PluginPromptPart> parts;
  final String? agent;
  final String? variant;
  final ({String providerID, String modelID})? model;

  const SendPromptBody({
    required this.parts,
    required this.agent,
    required this.variant,
    required this.model,
  });

  /// Converts our domain types to OpenCode's wire format.
  ///
  /// Both [PluginPromptPartFileUrl] and [PluginPromptPartFileData] map to
  /// OpenCode's single `file` part type — the difference is the URL scheme:
  /// - `fileUrl` → uses the URL as-is
  /// - `fileData` → constructs a `data:{mime};base64,{base64}` URL
  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return <String, dynamic>{
      "parts": parts.map((part) {
        return switch (part) {
          PluginPromptPartText(:final text) => <String, dynamic>{
            "type": "text",
            "text": text,
          },
          PluginPromptPartFilePath(:final mime, :final path, :final filename) => <String, dynamic>{
            "type": "file",
            "mime": mime,
            "url": Uri.file(path).toString(),
            "filename": ?filename,
          },
          PluginPromptPartFileUrl(:final mime, :final url, :final filename) => <String, dynamic>{
            "type": "file",
            "mime": mime,
            "url": url,
            "filename": ?filename,
          },
          PluginPromptPartFileData(:final mime, :final base64, :final filename) => <String, dynamic>{
            "type": "file",
            "mime": mime,
            "url": "data:$mime;base64,$base64",
            "filename": ?filename,
          },
        };
      }).toList(),
      "agent": ?agent,
      "variant": ?variant,
      if (selectedModel != null)
        "model": {
          "providerID": selectedModel.providerID,
          "modelID": selectedModel.modelID,
        },
    };
  }
}
