// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SessionNextRetryError {
  const SessionNextRetryError({
    required this.message,
    this.statusCode,
    required this.isRetryable,
    this.responseHeaders,
    this.responseBody,
    this.metadata,
  });

  factory SessionNextRetryError.fromJson(Map<String, dynamic> json) {
    return SessionNextRetryError(
      message: json["message"] as String,
      statusCode: (json["statusCode"] as num?)?.toDouble(),
      isRetryable: json["isRetryable"] as bool,
      responseHeaders: (json["responseHeaders"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      responseBody: json["responseBody"] as String?,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "statusCode": ?statusCode,
      "isRetryable": isRetryable,
      "responseHeaders": ?responseHeaders,
      "responseBody": ?responseBody,
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionNextRetryError &&
          other.message == message &&
          other.statusCode == statusCode &&
          other.isRetryable == isRetryable &&
          const DeepCollectionEquality().equals(other.responseHeaders, responseHeaders) &&
          other.responseBody == responseBody &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(message, statusCode, isRetryable, const DeepCollectionEquality().hash(responseHeaders), responseBody, const DeepCollectionEquality().hash(metadata));

  final String message;
  final double? statusCode;
  final bool isRetryable;
  final Map<String, String>? responseHeaders;
  final String? responseBody;
  final Map<String, String>? metadata;
}
