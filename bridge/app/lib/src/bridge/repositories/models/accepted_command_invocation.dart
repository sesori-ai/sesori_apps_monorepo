import "package:meta/meta.dart";

@immutable
class AcceptedCommandInvocation {
  final String invocationId;
  final String sessionId;
  final String pluginId;
  final String name;
  final String? arguments;
  final int acceptedAt;
  final String? backendMessageId;

  const AcceptedCommandInvocation({
    required this.invocationId,
    required this.sessionId,
    required this.pluginId,
    required this.name,
    required this.arguments,
    required this.acceptedAt,
    required this.backendMessageId,
  });

  AcceptedCommandInvocation withBackendMessageId({required String backendMessageId}) {
    return AcceptedCommandInvocation(
      invocationId: invocationId,
      sessionId: sessionId,
      pluginId: pluginId,
      name: name,
      arguments: arguments,
      acceptedAt: acceptedAt,
      backendMessageId: backendMessageId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AcceptedCommandInvocation &&
        other.invocationId == invocationId &&
        other.sessionId == sessionId &&
        other.pluginId == pluginId &&
        other.name == name &&
        other.arguments == arguments &&
        other.acceptedAt == acceptedAt &&
        other.backendMessageId == backendMessageId;
  }

  @override
  int get hashCode => Object.hash(
    invocationId,
    sessionId,
    pluginId,
    name,
    arguments,
    acceptedAt,
    backendMessageId,
  );
}
