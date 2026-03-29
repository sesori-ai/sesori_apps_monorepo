import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class SendPromptBody {
  final List<PluginPromptPart> parts;
  final String? agent;
  final ({String providerID, String modelID})? model;

  const SendPromptBody({
    required this.parts,
    required this.agent,
    required this.model,
  });

  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return <String, dynamic>{
      "parts": parts.map((part) {
        return switch (part) {
          PluginPromptPartText(:final text) => <String, dynamic>{
            "type": "text",
            "text": text,
          },
        };
      }).toList(),
      "agent": ?agent,
      if (selectedModel != null)
        "model": {
          "providerID": selectedModel.providerID,
          "modelID": selectedModel.modelID,
        },
    };
  }
}
