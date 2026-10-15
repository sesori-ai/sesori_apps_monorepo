import "package:freezed_annotation/freezed_annotation.dart";

part "pending_external_action.freezed.dart";
part "pending_external_action.g.dart";

enum ExternalActionPurpose() {
  unknown,
  authorization,
  connectorConsent,
}

/// These choices describe the native request, not the connection's final state.
enum ExternalActionChoice() {
  unknown,
  accept,
  decline,
  cancel,
}

/// A native session request awaiting consent. Catalog setup and explicit server
/// authentication use their own contracts; neither fabricates a pending request.
/// The bridge validates launch destinations before returning this snapshot.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingExternalAction with _$PendingExternalAction {
  const factory({
    required String id,
    required String sessionID,
    required String? displaySessionId,
    required String title,
    required String message,
    required String authorizationUrl,
    @JsonKey(unknownEnumValue: ExternalActionPurpose.unknown) required ExternalActionPurpose purpose,
    @JsonKey(unknownEnumValue: ExternalActionChoice.unknown) required List<ExternalActionChoice> choices,
  }) = _PendingExternalAction;

  factory fromJson(Map<String, dynamic> json) => _$PendingExternalActionFromJson(json);
}

/// Response body for session-scoped external-action snapshot reads.
/// Destinations stay request-scoped; broadcasts carry only invalidation.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingExternalActionsResponse with _$PendingExternalActionsResponse {
  const factory({required List<PendingExternalAction> data}) = _PendingExternalActionsResponse;

  factory fromJson(Map<String, dynamic> json) => _$PendingExternalActionsResponseFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true)
sealed class ReplyToExternalActionRequest with _$ReplyToExternalActionRequest {
  const factory({
    required String requestId,
    required String sessionId,
    @JsonKey(unknownEnumValue: ExternalActionChoice.unknown) required ExternalActionChoice choice,
  }) = _ReplyToExternalActionRequest;

  factory fromJson(Map<String, dynamic> json) => _$ReplyToExternalActionRequestFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", copyWith: false, fromJson: true, toJson: true)
sealed class ExternalActionReplyResult with _$ExternalActionReplyResult {
  const factory unknown() = ExternalActionReplyUnknown;

  /// The native reply was accepted. This does not prove OAuth completion.
  const factory accepted() = ExternalActionReplyAccepted;
  const factory alreadySettled() = ExternalActionAlreadySettled;
  const factory unsupportedChoice() = ExternalActionUnsupportedChoice;

  factory fromJson(Map<String, dynamic> json) => _$ExternalActionReplyResultFromJson(json);
}
