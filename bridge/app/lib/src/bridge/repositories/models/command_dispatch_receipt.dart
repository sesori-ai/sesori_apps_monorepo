import "package:meta/meta.dart";

@immutable
class CommandDispatchReceipt {
  final String pluginId;
  final String sessionId;
  final String? backendMessageId;

  const CommandDispatchReceipt({
    required this.pluginId,
    required this.sessionId,
    required this.backendMessageId,
  });
}
