import "package:freezed_annotation/freezed_annotation.dart";

part "messages.freezed.dart";
part "messages.g.dart";

@Freezed(unionKey: "type", unionValueCase: FreezedUnionCase.snake)
sealed class RelayMessage with _$RelayMessage {
  @FreezedUnionValue("request")
  const factory RelayMessage.request({
    required String id,
    required String method,
    required String path,
    required Map<String, String> headers,
    required String? body,
  }) = RelayRequest;

  @FreezedUnionValue("response")
  const factory RelayMessage.response({
    required String id,
    required int status,
    required Map<String, String> headers,
    required String? body,
  }) = RelayResponse;

  @FreezedUnionValue("sse_event")
  const factory RelayMessage.sseEvent({required String data}) = RelaySseEvent;

  @FreezedUnionValue("sse_subscribe")
  const factory RelayMessage.sseSubscribe({required String path}) = RelaySseSubscribe;

  @FreezedUnionValue("sse_unsubscribe")
  const factory RelayMessage.sseUnsubscribe() = RelaySseUnsubscribe;

  @FreezedUnionValue("key_exchange")
  const factory RelayMessage.keyExchange({required String publicKey}) = RelayKeyExchange;

  @FreezedUnionValue("ready")
  const factory RelayMessage.ready({
    required String publicKey,
    required String roomKey,
  }) = RelayReady;

  @FreezedUnionValue("resume")
  const factory RelayMessage.resume() = RelayResume;

  @FreezedUnionValue("resume_ack")
  const factory RelayMessage.resumeAck() = RelayResumeAck;

  @FreezedUnionValue("rekey_required")
  const factory RelayMessage.rekeyRequired() = RelayRekeyRequired;

  @FreezedUnionValue("auth")
  const factory RelayMessage.auth({
    required String token,
    required String role,
  }) = AuthRelayMessage;

  factory RelayMessage.fromJson(Map<String, dynamic> json) => _$RelayMessageFromJson(json);
}
