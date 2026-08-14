import "../mappers/pi_message_identity_builder.dart";

final class PiMessageIdentityTracker({required final String pluginId}) {
  final String _pluginId = pluginId;
  final Map<String, PiMessageIdentityBuilder> _sessions = {};

  T hydrate<T>({
    required String sessionId,
    required T Function(PiMessageIdentityBuilder identities) map,
  }) {
    final candidate = PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId);
    final result = map(candidate);
    forSession(sessionId: sessionId).replaceWith(other: candidate);
    return result;
  }

  PiMessageIdentityBuilder forSession({required String sessionId}) => _sessions.putIfAbsent(
    sessionId,
    () => PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId),
  );

  void forgetSession({required String sessionId}) => _sessions.remove(sessionId);
}
