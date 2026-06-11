// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class ProviderAuthError {
  const ProviderAuthError({
    required this.name,
    required this.data,
  });

  factory ProviderAuthError.fromJson(Map<String, dynamic> json) {
    return ProviderAuthError(
      name: json["name"] as String,
      data: ProviderAuthErrorData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data.toJson(),
    };
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
    required this.providerID,
    required this.message,
  });

  factory ProviderAuthErrorData.fromJson(Map<String, dynamic> json) {
    return ProviderAuthErrorData(
      providerID: json["providerID"] as String,
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": providerID,
      "message": message,
    };
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
