class SendCommandBody {
  final String command;
  final String arguments;

  const SendCommandBody({
    required this.command,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
    "command": command,
    "arguments": arguments,
  };
}
