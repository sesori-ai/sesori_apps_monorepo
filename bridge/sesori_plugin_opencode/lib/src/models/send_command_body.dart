class const SendCommandBody({
  required final String command,
  required final String arguments,
  required final String? agent,
  required final String? variant,
  required final ({String providerID, String modelID})? model,
}) {
  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return {
      "command": command,
      "arguments": arguments,
      "agent": ?agent,
      "variant": ?variant,
      if (selectedModel != null) "model": "${selectedModel.providerID}/${selectedModel.modelID}",
    };
  }
}
