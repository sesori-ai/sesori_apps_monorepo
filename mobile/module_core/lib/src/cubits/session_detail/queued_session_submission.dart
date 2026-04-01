sealed class QueuedSessionSubmission {
  const QueuedSessionSubmission();

  String get displayText;
  bool get isCommand;
}

class QueuedPromptSubmission extends QueuedSessionSubmission {
  final String text;

  const QueuedPromptSubmission({required this.text});

  @override
  String get displayText => text;

  @override
  bool get isCommand => false;
}

class QueuedCommandSubmission extends QueuedSessionSubmission {
  final String command;
  final String arguments;

  const QueuedCommandSubmission({
    required this.command,
    required this.arguments,
  });

  @override
  String get displayText => arguments.trim().isEmpty ? "/$command" : "/$command ${arguments.trim()}";

  @override
  bool get isCommand => true;
}
