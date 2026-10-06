// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';

@immutable
class SessionStructuredError {
  const SessionStructuredError({
    required this.type,
    required this.message,
    required this.status,
    required this.response,
  });

  factory SessionStructuredError.fromJson(Map<String, dynamic> json) {
    return SessionStructuredError(
      type: json["type"] as String,
      message: json["message"] as String,
      status: (json["status"] as num?)?.toInt(),
      response: json["response"] == null ? null : SessionStructuredErrorResponse.fromJson(json["response"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "message": message,
      "status": ?status,
      "response": ?response?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionStructuredError copyWith({
    String? type,
    String? message,
    int? status,
    SessionStructuredErrorResponse? response,
  }) {
    return SessionStructuredError(
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
      response: response ?? this.response,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStructuredError &&
          other.type == type &&
          other.message == message &&
          other.status == status &&
          other.response == response);

  @override
  int get hashCode => Object.hash(type, message, status, response);

  final String type;
  final String message;
  final int? status;
  final SessionStructuredErrorResponse? response;
}

@immutable
class SessionStructuredErrorResponse {
  const SessionStructuredErrorResponse({
    required this.body,
  });

  factory SessionStructuredErrorResponse.fromJson(Map<String, dynamic> json) {
    return SessionStructuredErrorResponse(
      body: json["body"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "body": body,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionStructuredErrorResponse copyWith({
    String? body,
  }) {
    return SessionStructuredErrorResponse(
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStructuredErrorResponse &&
          other.body == body);

  @override
  int get hashCode => body.hashCode;

  final String body;
}
