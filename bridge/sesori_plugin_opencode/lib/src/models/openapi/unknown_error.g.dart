// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class UnknownError {
  const UnknownError({
    this.name = '',
    required this.data,
  });

  factory UnknownError.fromJson(Map<String, dynamic> json) {
    return UnknownError(
      name: (json["name"] ?? '') as String,
      data: UnknownErrorData.fromJson((json["data"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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
  UnknownError copyWith({
    String? name,
    UnknownErrorData? data,
  }) {
    return UnknownError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final UnknownErrorData data;
}

@immutable
class UnknownErrorData {
  const UnknownErrorData({
    this.message = '',
    this.ref,
  });

  factory UnknownErrorData.fromJson(Map<String, dynamic> json) {
    return UnknownErrorData(
      message: (json["message"] ?? '') as String,
      ref: json["ref"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "ref": ?ref,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  UnknownErrorData copyWith({
    String? message,
    String? ref,
  }) {
    return UnknownErrorData(
      message: message ?? this.message,
      ref: ref ?? this.ref,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownErrorData &&
          other.message == message &&
          other.ref == ref);

  @override
  int get hashCode => Object.hash(message, ref);

  final String message;
  final String? ref;
}
