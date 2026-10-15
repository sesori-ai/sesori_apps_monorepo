// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'connection_info.g.dart';
import 'connection_status.g.dart';

@immutable
class ConnectionCredentialInfo implements ConnectionInfo {
  const ConnectionCredentialInfo({
    required this.id,
    required this.label,
    required this.method,
    required this.status,
  });

  factory ConnectionCredentialInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionCredentialInfo(
      id: json["id"] as String,
      label: json["label"] as String,
      method: json["method"] == null ? null : ConnectionCredentialInfoMethod.fromJson(json["method"] as String),
      status: json["status"] == null ? null : ConnectionStatus.fromJson(json["status"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "credential",
      "id": id,
      "label": label,
      "method": ?method?.toJson(),
      "status": ?status?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ConnectionCredentialInfo copyWith({
    String? id,
    String? label,
    ConnectionCredentialInfoMethod? method,
    ConnectionStatus? status,
  }) {
    return ConnectionCredentialInfo(
      id: id ?? this.id,
      label: label ?? this.label,
      method: method ?? this.method,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionCredentialInfo &&
          other.id == id &&
          other.label == label &&
          other.method == method &&
          other.status == status);

  @override
  int get hashCode => Object.hash(id, label, method, status);

  final String id;
  final String label;
  final ConnectionCredentialInfoMethod? method;
  final ConnectionStatus? status;
}

enum ConnectionCredentialInfoMethod {
  @JsonValue("key")
  key,
  @JsonValue("oauth")
  oauth,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ConnectionCredentialInfoMethod fromJson(String value) {
    switch (value) {
      case "key":
        return ConnectionCredentialInfoMethod.key;
      case "oauth":
        return ConnectionCredentialInfoMethod.oauth;
      default:
        return ConnectionCredentialInfoMethod.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ConnectionCredentialInfoMethod.key:
        return "key";
      case ConnectionCredentialInfoMethod.oauth:
        return "oauth";
      case ConnectionCredentialInfoMethod.unknown:
        return 'unknown';
    }
  }
}
