import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";

/// Records the sessions whose arming was announced. Nothing else is expected.
final class RecordingArmingMutations() implements SessionMutationDispatcher {
  final List<String> armedSessionIds = [];

  @override
  Future<void> armingUpdated({required String sessionId}) async => armedSessionIds.add(sessionId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
