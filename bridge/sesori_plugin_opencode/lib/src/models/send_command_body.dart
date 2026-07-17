class SendCommandBody {
  final String? messageID;
  final String command;
  final String arguments;
  final String? agent;
  final String? variant;
  final ({String providerID, String modelID})? model;

  const SendCommandBody({
    required this.messageID,
    required this.command,
    required this.arguments,
    required this.agent,
    required this.variant,
    required this.model,
  });

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
