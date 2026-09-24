import "package:sesori_bridge/src/repositories/session_continuation_repository.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Fixtures for existing tests whose sessions have no continuation observation.
/// Continuation behavior tests use real storage and projection instead.
final class const EmptySessionContinuations() implements SessionContinuationRepository {
  @override
  Future<bool> cancelCurrentObservationAlreadyReserved({required String sessionId}) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const PassThroughSessionViews() implements SessionViewService {
  @override
  Future<Session> enrich({required Session session}) async => session;

  @override
  Future<List<Session>> enrichMany({required List<Session> sessions}) async => sessions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class const UnusedContinuationMutations() implements SessionMutationDispatcher {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
