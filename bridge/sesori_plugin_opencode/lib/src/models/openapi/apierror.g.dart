// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class APIError {
  const APIError({
    required this.name,
    required this.data,
  });

  factory APIError.fromJson(Map<String, dynamic> json) {
    return APIError(
      name: json["name"] as String,
      data: APIErrorData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  APIError copyWith({
    String? name,
    APIErrorData? data,
  }) {
    return APIError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is APIError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final APIErrorData data;
}

@immutable
class APIErrorData {
  const APIErrorData({
    required this.message,
    required this.statusCode,
    required this.isRetryable,
    required this.responseHeaders,
    required this.responseBody,
    required this.metadata,
  });

  factory APIErrorData.fromJson(Map<String, dynamic> json) {
    return APIErrorData(
      message: json["message"] as String,
      statusCode: (json["statusCode"] as num?)?.toInt(),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  APIErrorData copyWith({
    String? message,
    int? statusCode,
    bool? isRetryable,
    Map<String, String>? responseHeaders,
    String? responseBody,
    Map<String, String>? metadata,
  }) {
    return APIErrorData(
      message: message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      isRetryable: isRetryable ?? this.isRetryable,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is APIErrorData &&
          other.message == message &&
          other.statusCode == statusCode &&
          other.isRetryable == isRetryable &&
          const DeepCollectionEquality().equals(other.responseHeaders, responseHeaders) &&
          other.responseBody == responseBody &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(message, statusCode, isRetryable, const DeepCollectionEquality().hash(responseHeaders), responseBody, const DeepCollectionEquality().hash(metadata));

  final String message;
  final int? statusCode;
  final bool isRetryable;
  final Map<String, String>? responseHeaders;
  final String? responseBody;
  final Map<String, String>? metadata;
}
