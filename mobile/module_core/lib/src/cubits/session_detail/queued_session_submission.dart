import "../../platform/media_picker.dart";

class QueuedSessionSubmission {
  final String text;
  final String? command;
  final List<PickedMedia> attachments;

  const QueuedSessionSubmission({
    required this.text,
    this.command,
    this.attachments = const [],
  });

  String get displayText {
    if (command != null) {
      return text.trim().isEmpty ? "/$command" : "/$command ${text.trim()}";
    }
    if (text.trim().isEmpty && attachments.isNotEmpty) {
      return attachments.length == 1 ? "1 image" : "${attachments.length} images";
    }
    return text;
  }

  bool get isCommand => command != null;
}
