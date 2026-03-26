import "package:freezed_annotation/freezed_annotation.dart";

part "message.freezed.dart";

part "message.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Message with _$Message {
  const factory Message({
    required String role,
    required String id,
    required String sessionID,
    String? agent,
    String? modelID,
    String? providerID,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
