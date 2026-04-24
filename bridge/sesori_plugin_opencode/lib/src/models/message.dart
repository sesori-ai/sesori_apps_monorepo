import "package:freezed_annotation/freezed_annotation.dart";

part "message.freezed.dart";

part "message.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Message with _$Message {
  const factory Message({
    required String role,
    required String id,
    required String sessionID,
    required String? parentID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required double? cost,
    required MessageTokens? tokens,
    required MessageTime? time,
    required String? finish,
    required MessageError? error,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageError with _$MessageError {
  const factory MessageError({
    required String name,
    required MessageErrorData data,
  }) = _MessageError;

  factory MessageError.fromJson(Map<String, dynamic> json) => _$MessageErrorFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageErrorData with _$MessageErrorData {
  const factory MessageErrorData({
    required String message,
    required String? responseBody,
    required int? statusCode,
    required bool? isRetryable,
    required Map<String, String>? metadata,
  }) = _MessageErrorData;

  factory MessageErrorData.fromJson(Map<String, dynamic> json) => _$MessageErrorDataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageTime with _$MessageTime {
  const factory MessageTime({
    required int created,
    required int? completed,
  }) = _MessageTime;

  factory MessageTime.fromJson(Map<String, dynamic> json) => _$MessageTimeFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageTokens with _$MessageTokens {
  const factory MessageTokens({
    @Default(0) int input,
    @Default(0) int output,
    @Default(0) int reasoning,
    required TokenCache? cache,
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
