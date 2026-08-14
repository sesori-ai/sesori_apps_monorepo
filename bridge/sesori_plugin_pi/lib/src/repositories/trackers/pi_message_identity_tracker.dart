import "../mappers/pi_message_identity_builder.dart";

final class PiMessageIdentityTracker({required final String pluginId}) {
  final String _pluginId = pluginId;
  final Map<String, PiMessageIdentityBuilder> _sessions = {};

  PiMessageIdentityBuilder rebuild({required String sessionId}) => forSession(sessionId: sessionId)..reset();

  PiMessageIdentityBuilder forSession({required String sessionId}) => _sessions.putIfAbsent(
    sessionId,
    () => PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId),
  );

  void forgetSession({required String sessionId}) => _sessions.remove(sessionId);
}
