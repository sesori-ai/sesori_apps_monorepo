// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class StructuredOutputError {
  const StructuredOutputError({
    this.name = '',
    required this.data,
  });

  factory StructuredOutputError.fromJson(Map<String, dynamic> json) {
    return StructuredOutputError(
      name: (json["name"] ?? '') as String,
      data: StructuredOutputErrorData.fromJson((json["data"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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
  StructuredOutputError copyWith({
    String? name,
    StructuredOutputErrorData? data,
  }) {
    return StructuredOutputError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StructuredOutputError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final StructuredOutputErrorData data;
}

@immutable
class StructuredOutputErrorData {
  const StructuredOutputErrorData({
    this.message = '',
    this.retries = 0,
  });

  factory StructuredOutputErrorData.fromJson(Map<String, dynamic> json) {
    return StructuredOutputErrorData(
      message: (json["message"] ?? '') as String,
      retries: ((json["retries"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "retries": retries,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  StructuredOutputErrorData copyWith({
    String? message,
    int? retries,
  }) {
    return StructuredOutputErrorData(
      message: message ?? this.message,
      retries: retries ?? this.retries,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StructuredOutputErrorData &&
          other.message == message &&
          other.retries == retries);

  @override
  int get hashCode => Object.hash(message, retries);

  final String message;
  final int retries;
}
