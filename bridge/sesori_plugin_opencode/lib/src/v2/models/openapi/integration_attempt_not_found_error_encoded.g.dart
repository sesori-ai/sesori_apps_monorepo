// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';

@immutable
class IntegrationAttemptNotFoundErrorEncoded {
  const IntegrationAttemptNotFoundErrorEncoded({
    required this.tag,
    required this.integrationID,
    required this.attemptID,
    required this.message,
  });

  factory IntegrationAttemptNotFoundErrorEncoded.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptNotFoundErrorEncoded(
      tag: json["_tag"] as String,
      integrationID: json["integrationID"] as String,
      attemptID: json["attemptID"] as String,
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "integrationID": integrationID,
      "attemptID": attemptID,
      "message": message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptNotFoundErrorEncoded copyWith({
    String? tag,
    String? integrationID,
    String? attemptID,
    String? message,
  }) {
    return IntegrationAttemptNotFoundErrorEncoded(
      tag: tag ?? this.tag,
      integrationID: integrationID ?? this.integrationID,
      attemptID: attemptID ?? this.attemptID,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptNotFoundErrorEncoded &&
          other.tag == tag &&
          other.integrationID == integrationID &&
          other.attemptID == attemptID &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, integrationID, attemptID, message);

  final String tag;
  final String integrationID;
  final String attemptID;
  final String message;
}
