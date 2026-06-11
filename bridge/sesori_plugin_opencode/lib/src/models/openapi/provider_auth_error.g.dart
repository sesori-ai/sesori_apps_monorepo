// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class ProviderAuthError {
  const ProviderAuthError({
    this.name = '',
    required this.data,
  });

  factory ProviderAuthError.fromJson(Map<String, dynamic> json) {
    return ProviderAuthError(
      name: (json["name"] ?? '') as String,
      data: ProviderAuthErrorData.fromJson((json["data"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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
  ProviderAuthError copyWith({
    String? name,
    ProviderAuthErrorData? data,
  }) {
    return ProviderAuthError(
      name: name ?? this.name,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderAuthError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ProviderAuthErrorData data;
}

@immutable
class ProviderAuthErrorData {
  const ProviderAuthErrorData({
    this.providerID = '',
    this.message = '',
  });

  factory ProviderAuthErrorData.fromJson(Map<String, dynamic> json) {
    return ProviderAuthErrorData(
      providerID: (json["providerID"] ?? '') as String,
      message: (json["message"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": providerID,
      "message": message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderAuthErrorData copyWith({
    String? providerID,
    String? message,
  }) {
    return ProviderAuthErrorData(
      providerID: providerID ?? this.providerID,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderAuthErrorData &&
          other.providerID == providerID &&
          other.message == message);

  @override
  int get hashCode => Object.hash(providerID, message);

  final String providerID;
  final String message;
}
