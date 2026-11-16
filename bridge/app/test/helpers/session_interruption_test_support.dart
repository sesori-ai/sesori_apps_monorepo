import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_interruption_repository.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";

/// For tests whose sessions never have an interruption. Interruption behavior
/// tests use real storage instead.
final class const NoSessionInterruptions() implements SessionInterruptionRepository {
  @override
  Future<bool> acknowledge({required String sessionId}) async => false;

  @override
  Future<bool> reanchor({required String sessionId, required Map<String, String> replacementIds}) async => false;

  @override
  Future<bool> hasRunningTurn({required String sessionId}) async => false;

  @override
  Future<Map<String, SessionInterruptionDto>> readMany({required Set<String> sessionIds}) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the sessions whose interruption changed or was acknowledged.
final class RecordingInterruptionMutations() implements SessionMutationDispatcher {
  final List<String> updated = [];
  final List<String> acknowledged = [];

  @override
  Future<void> acknowledgeInterruption({required String sessionId}) async => acknowledged.add(sessionId);

  @override
  Future<void> interruptionUpdated({required String sessionId}) async => updated.add(sessionId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
