import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const SendPromptBody({
  /// Id OpenCode should give the user message it creates, or null to let
  /// OpenCode name it. Naming it here is what links the message OpenCode
  /// publishes back to the send that caused it.
  required final String? messageID,
  required final List<PluginPromptPart> parts,
  required final String? agent,
  required final String? variant,
  required final ({String providerID, String modelID})? model,
  required final bool noReply,
}) {
  /// Converts our domain types to OpenCode's wire format.
  ///
  /// Both [PluginPromptPartFileUrl] and [PluginPromptPartFileData] map to
  /// OpenCode's single `file` part type — the difference is the URL scheme:
  /// - `fileUrl` → uses the URL as-is
  /// - `fileData` → constructs a `data:{mime};base64,{base64}` URL
  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return <String, dynamic>{
      "messageID": ?messageID,
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
      if (noReply) "noReply": true,
    };
  }
}
