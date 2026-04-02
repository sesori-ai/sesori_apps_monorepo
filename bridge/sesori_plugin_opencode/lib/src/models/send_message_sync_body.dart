class SendMessageSyncBody {
  final List<Map<String, dynamic>> parts;
  final String? system;
  final ({String providerID, String modelID})? model;

  const SendMessageSyncBody({
    required this.parts,
    required this.system,
    required this.model,
  });

  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return <String, dynamic>{
      "parts": parts,
      "system": ?system,
      if (selectedModel != null)
        "model": {
          "providerID": selectedModel.providerID,
          "modelID": selectedModel.modelID,
        },
    };
  }
}
