import "package:freezed_annotation/freezed_annotation.dart";

part "new_session_backend_scope.freezed.dart";

@Freezed()
sealed class const NewSessionBackendScopeTransition._() with _$NewSessionBackendScopeTransition {
  const factory NewSessionBackendScopeTransition.retained({required String bridgeId}) =
      NewSessionBackendScopeRetainedTransition;

  const factory NewSessionBackendScopeTransition.invalidated({required String? bridgeId}) =
      NewSessionBackendScopeInvalidatedTransition;

  bool get retainsBackendState => this is NewSessionBackendScopeRetainedTransition;

  NewSessionBackendScope get scope => NewSessionBackendScope.verified(
    bridgeId: switch (this) {
      NewSessionBackendScopeRetainedTransition(:final bridgeId) => bridgeId,
      NewSessionBackendScopeInvalidatedTransition(:final bridgeId) => bridgeId,
    },
  );
}

@Freezed()
sealed class const NewSessionBackendScope._() with _$NewSessionBackendScope {
  const factory NewSessionBackendScope.unverified({required String? lastIdentifiedBridgeId}) =
      NewSessionBackendScopeUnverified;

  const factory NewSessionBackendScope.verified({required String? bridgeId}) = NewSessionBackendScopeVerified;

  bool get isVerified => this is NewSessionBackendScopeVerified;

  String? get lastIdentifiedBridgeId => switch (this) {
    NewSessionBackendScopeUnverified(:final lastIdentifiedBridgeId) => lastIdentifiedBridgeId,
    NewSessionBackendScopeVerified(:final bridgeId) => bridgeId,
  };

  String? get identifiedBridgeId => switch (this) {
    NewSessionBackendScopeUnverified() => null,
    NewSessionBackendScopeVerified(:final bridgeId) => bridgeId,
  };

  NewSessionBackendScope invalidate() =>
      NewSessionBackendScope.unverified(lastIdentifiedBridgeId: lastIdentifiedBridgeId);

  NewSessionBackendScopeTransition transitionToDiscovered({required String? bridgeId}) {
    final previousBridgeId = lastIdentifiedBridgeId;
    return previousBridgeId != null && bridgeId != null && previousBridgeId == bridgeId
        ? NewSessionBackendScopeTransition.retained(bridgeId: bridgeId)
        : NewSessionBackendScopeTransition.invalidated(bridgeId: bridgeId);
  }
}
