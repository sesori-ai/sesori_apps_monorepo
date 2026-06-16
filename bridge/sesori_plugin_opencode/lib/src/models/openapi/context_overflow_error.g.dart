// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class ContextOverflowError {
  const ContextOverflowError({
    required this.name,
    required this.data,
  });

  factory ContextOverflowError.fromJson(Map<String, dynamic> json) {
    return ContextOverflowError(
      name: json["name"] as String,
      data: ContextOverflowErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
  ContextOverflowError copyWith({
    String? name,
    ContextOverflowErrorData? data,
  }) {
    return ContextOverflowError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextOverflowError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ContextOverflowErrorData data;
}

@immutable
class ContextOverflowErrorData {
  const ContextOverflowErrorData({
    required this.message,
    required this.responseBody,
  });

  factory ContextOverflowErrorData.fromJson(Map<String, dynamic> json) {
    return ContextOverflowErrorData(
      message: json["message"] as String,
      responseBody: json["responseBody"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "responseBody": ?responseBody,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ContextOverflowErrorData copyWith({
    String? message,
    String? responseBody,
  }) {
    return ContextOverflowErrorData(
      message: message ?? this.message,
      responseBody: responseBody ?? this.responseBody,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextOverflowErrorData &&
          other.message == message &&
          other.responseBody == responseBody);

  @override
  int get hashCode => Object.hash(message, responseBody);

  final String message;
  final String? responseBody;
}
