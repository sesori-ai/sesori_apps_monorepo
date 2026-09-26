// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';

@immutable
class SessionStructuredError {
  const SessionStructuredError({
    required this.type,
    required this.message,
    required this.status,
  });

  factory SessionStructuredError.fromJson(Map<String, dynamic> json) {
    return SessionStructuredError(
      type: json["type"] as String,
      message: json["message"] as String,
      status: (json["status"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "message": message,
      "status": ?status,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionStructuredError copyWith({
    String? type,
    String? message,
    int? status,
  }) {
    return SessionStructuredError(
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStructuredError &&
          other.type == type &&
          other.message == message &&
          other.status == status);

  @override
  int get hashCode => Object.hash(type, message, status);

  final String type;
  final String message;
  final int? status;
}
