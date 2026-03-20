import "package:freezed_annotation/freezed_annotation.dart";

part "message.freezed.dart";

part "message.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Message with _$Message {
  const factory Message({
    required String role,
    required String id,
    required String sessionID,
    String? parentID,
    String? agent,
    String? modelID,
    String? providerID,
    double? cost,
    MessageTokens? tokens,
    MessageTime? time,
    String? finish,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageTime with _$MessageTime {
  const factory MessageTime({
    required int created,
    int? completed,
  }) = _MessageTime;

  factory MessageTime.fromJson(Map<String, dynamic> json) => _$MessageTimeFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageTokens with _$MessageTokens {
  const factory MessageTokens({
    @Default(0) int input,
    @Default(0) int output,
    @Default(0) int reasoning,
    TokenCache? cache,
  }) = _MessageTokens;

  factory MessageTokens.fromJson(Map<String, dynamic> json) => _$MessageTokensFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class TokenCache with _$TokenCache {
  const factory TokenCache({
    @Default(0) int read,
    @Default(0) int write,
  }) = _TokenCache;

  factory TokenCache.fromJson(Map<String, dynamic> json) => _$TokenCacheFromJson(json);
}
