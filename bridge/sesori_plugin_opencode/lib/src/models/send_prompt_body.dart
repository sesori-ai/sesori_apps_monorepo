import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const SendPromptBody({
  /// Existing OpenCode user-message id to reuse, or null to let OpenCode name
  /// a new message. Sesori reserves a server-named empty message, records its
  /// id, then reuses it here so correlation never depends on the bridge clock.
  required final String? messageID,
  required final List<PluginPromptPart> parts,
  required final String? agent,
  required final String? variant,
  required final ({String providerID, String modelID})? model,
  required final bool noReply,
  required final bool syntheticText,
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
            if (syntheticText) "synthetic": true,
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
