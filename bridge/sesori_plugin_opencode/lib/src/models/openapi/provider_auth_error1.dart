// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class ProviderAuthError1 {
  const ProviderAuthError1({
    required this.name,
    required this.data,
  });

  factory ProviderAuthError1.fromJson(Map<String, dynamic> json) {
    return ProviderAuthError1(
      name: json["name"] as String,
      data: ProviderAuthError1Data.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is ProviderAuthError1 &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ProviderAuthError1Data data;
}

@immutable
class ProviderAuthError1Data {
  const ProviderAuthError1Data({
    this.providerID,
    this.field,
    this.message,
    this.kind,
  });

  factory ProviderAuthError1Data.fromJson(Map<String, dynamic> json) {
    return ProviderAuthError1Data(
      providerID: json["providerID"] as String?,
      field: json["field"] as String?,
      message: json["message"] as String?,
      kind: json["kind"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": ?providerID,
      "field": ?field,
      "message": ?message,
      "kind": ?kind,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderAuthError1Data &&
          other.providerID == providerID &&
          other.field == field &&
          other.message == message &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(providerID, field, message, kind);

  final String? providerID;
  final String? field;
  final String? message;
  final String? kind;
}
