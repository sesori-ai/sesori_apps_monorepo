import "../mappers/pi_message_identity_builder.dart";

final class PiMessageIdentityTracker({required final String pluginId}) {
  final String _pluginId = pluginId;
  final Map<String, PiMessageIdentityBuilder> _sessions = {};

  T hydrate<T>({
    required String sessionId,
    required T Function(PiMessageIdentityBuilder identities) map,
  }) => beginHydration(sessionId: sessionId).complete(map: map);

  PiMessageIdentityHydration beginHydration({required String sessionId}) {
    final target = forSession(sessionId: sessionId);
    return PiMessageIdentityHydration(
      target: target,
      baseline: target.snapshot(),
      pluginId: _pluginId,
      sessionId: sessionId,
    );
  }

  PiMessageIdentityBuilder forSession({required String sessionId}) => _sessions.putIfAbsent(
    sessionId,
    () => PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId),
  );

  void forgetSession({required String sessionId}) => _sessions.remove(sessionId);
}

final class PiMessageIdentityHydration({
  required final PiMessageIdentityBuilder target,
  required final PiMessageIdentitySnapshot baseline,
  required final String pluginId,
  required final String sessionId,
}) {
  T complete<T>({required T Function(PiMessageIdentityBuilder identities) map}) {
    final candidate = PiMessageIdentityBuilder(pluginId: pluginId, sessionId: sessionId);
    final result = map(candidate);
    target.replaceHydrated(other: candidate, since: baseline);
    return result;
  }
}
