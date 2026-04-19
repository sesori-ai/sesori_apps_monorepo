class QueuedSessionSubmission {
  final String text;
  final String? command;

  const QueuedSessionSubmission({required this.text, this.command});

  String get displayText => command != null
      ? text.trim().isEmpty
            ? "/$command"
            : "/$command ${text.trim()}"
      : text;

  bool get isCommand => command != null;
}
