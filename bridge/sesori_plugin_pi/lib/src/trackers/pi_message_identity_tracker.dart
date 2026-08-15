import "../repositories/mappers/pi_message_identity_builder.dart";

final class PiMessageIdentityTracker({required final String pluginId}) {
  final String _pluginId = pluginId;
  final Map<String, PiMessageIdentityBuilder> _sessions = {};
  final Map<String, int> _nextHydrationGenerations = {};
  final Map<String, int> _committedHydrationGenerations = {};

  T hydrate<T>({
    required String sessionId,
    required T Function(PiMessageIdentityBuilder identities) map,
  }) => beginHydration(sessionId: sessionId).complete(map: map);

  PiMessageIdentityHydration beginHydration({required String sessionId}) {
    final target = forSession(sessionId: sessionId);
    final generation = (_nextHydrationGenerations[sessionId] ?? 0) + 1;
    _nextHydrationGenerations[sessionId] = generation;
    return PiMessageIdentityHydration(
      tracker: this,
      target: target,
      baseline: target.snapshot(),
      pluginId: _pluginId,
      sessionId: sessionId,
      generation: generation,
    );
  }

  PiMessageIdentityBuilder forSession({required String sessionId}) => _sessions.putIfAbsent(
    sessionId,
    () => PiMessageIdentityBuilder(pluginId: _pluginId, sessionId: sessionId),
  );

  void forgetSession({required String sessionId}) {
    _sessions.remove(sessionId);
    _nextHydrationGenerations.remove(sessionId);
    _committedHydrationGenerations.remove(sessionId);
  }

  void _commit({
    required String sessionId,
    required int generation,
    required PiMessageIdentityBuilder target,
    required PiMessageIdentityBuilder candidate,
    required PiMessageIdentitySnapshot baseline,
  }) {
    if (!identical(_sessions[sessionId], target)) return;
    if (generation < (_committedHydrationGenerations[sessionId] ?? 0)) return;
    target.replaceHydrated(other: candidate, since: baseline);
    _committedHydrationGenerations[sessionId] = generation;
  }
}

final class PiMessageIdentityHydration({
  required final PiMessageIdentityTracker tracker,
  required final PiMessageIdentityBuilder target,
  required final PiMessageIdentitySnapshot baseline,
  required final String pluginId,
  required final String sessionId,
  required final int generation,
}) {
  T complete<T>({required T Function(PiMessageIdentityBuilder identities) map}) {
    final candidate = PiMessageIdentityBuilder(pluginId: pluginId, sessionId: sessionId);
    final result = map(candidate);
    tracker._commit(
      sessionId: sessionId,
      generation: generation,
      target: target,
      candidate: candidate,
      baseline: baseline,
    );
    return result;
  }
}
