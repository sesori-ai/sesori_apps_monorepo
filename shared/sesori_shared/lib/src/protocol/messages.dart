import "package:freezed_annotation/freezed_annotation.dart";

import "../models/sesori/message_part.dart";

part "messages.freezed.dart";
part "messages.g.dart";

@Freezed(unionKey: "type", unionValueCase: FreezedUnionCase.snake)
sealed class RelayMessage with _$RelayMessage {
  @FreezedUnionValue("request")
  const factory request({
    required String id,
    required String method,
    required String path,
    required Map<String, String> headers,
    required String? body,
  }) = RelayRequest;

  @FreezedUnionValue("response")
  const factory response({
    required String id,
    required int status,
    required Map<String, String> headers,
    required String? body,
  }) = RelayResponse;

  @FreezedUnionValue("sse_event")
  const factory sseEvent({required String data}) = RelaySseEvent;

  @FreezedUnionValue("sse_subscribe")
  const factory sseSubscribe({
    required String path,
    // COMPATIBILITY 2026-08-10 (v1.8.0): Apps predating stored transcript images omit attachmentDelivery and require inline payloads. Remove @Default after the minimum supported app sends this field.
    @Default(MessageAttachmentDelivery.inline) MessageAttachmentDelivery attachmentDelivery,
  }) = RelaySseSubscribe;

  @FreezedUnionValue("sse_unsubscribe")
  const factory sseUnsubscribe() = RelaySseUnsubscribe;

  /// Connection-scoped declaration of which session the phone is currently
  /// viewing (the session detail screen). [sessionId] is null when the phone
  /// is not viewing any session. Fire-and-forget control message (no response),
  /// analogous to [RelaySseSubscribe]; the bridge tracks it per-connection and
  /// auto-releases it on disconnect.
  @FreezedUnionValue("session_view")
  const factory sessionView({required String? sessionId}) = RelaySessionView;

  /// Connection-scoped declaration of which project the phone is currently
  /// viewing. [projectId] is null when the phone is not viewing any project.
  /// This is a fire-and-forget control message with no response.
  @FreezedUnionValue("project_view")
  const factory projectView({required String? projectId}) = RelayProjectView;

  @FreezedUnionValue("key_exchange")
  const factory keyExchange({required String publicKey}) = RelayKeyExchange;

  @FreezedUnionValue("ready")
  const factory ready({
    required String publicKey,
    required String roomKey,
  }) = RelayReady;

  @FreezedUnionValue("resume")
  const factory resume() = RelayResume;

  @FreezedUnionValue("resume_ack")
  const factory resumeAck() = RelayResumeAck;

  @FreezedUnionValue("rekey_required")
  const factory rekeyRequired() = RelayRekeyRequired;

  @FreezedUnionValue("auth")
  const factory auth({
    required String token,
    required String role,
    @JsonKey(includeIfNull: false) required String? bridgeId,
  }) = AuthRelayMessage;

  factory fromJson(Map<String, dynamic> json) => _$RelayMessageFromJson(json);
}
