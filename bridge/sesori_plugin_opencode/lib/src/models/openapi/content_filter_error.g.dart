// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class ContentFilterError {
  const ContentFilterError({
    required this.name,
    required this.data,
  });

  factory ContentFilterError.fromJson(Map<String, dynamic> json) {
    return ContentFilterError(
      name: json["name"] as String,
      data: ContentFilterErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
  ContentFilterError copyWith({
    String? name,
    ContentFilterErrorData? data,
  }) {
    return ContentFilterError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentFilterError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ContentFilterErrorData data;
}

@immutable
class ContentFilterErrorData {
  const ContentFilterErrorData({
    required this.message,
  });

  factory ContentFilterErrorData.fromJson(Map<String, dynamic> json) {
    return ContentFilterErrorData(
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ContentFilterErrorData copyWith({
    String? message,
  }) {
    return ContentFilterErrorData(
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentFilterErrorData &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
