class const SendCommandBody({
  /// Existing server-named user-message id the command should reuse, or null
  /// to let OpenCode name a new message.
  required final String? messageID,
  required final String command,
  required final String arguments,
  required final String? agent,
  required final String? variant,
  required final ({String providerID, String modelID})? model,
}) {
  Map<String, dynamic> toJson() {
    final selectedModel = model;
    return {
      "messageID": ?messageID,
      "command": command,
      "arguments": arguments,
      "agent": ?agent,
      "variant": ?variant,
      if (selectedModel != null) "model": "${selectedModel.providerID}/${selectedModel.modelID}",
    };
  }
}
