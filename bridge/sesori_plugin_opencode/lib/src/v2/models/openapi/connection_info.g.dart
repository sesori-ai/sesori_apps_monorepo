// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'connection_status.g.dart';

@immutable
sealed class ConnectionInfo {
  const ConnectionInfo();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ConnectionInfo.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "credential":
        return ConnectionCredentialInfo.fromJson(map);
      case "env":
        return ConnectionEnvInfo.fromJson(map);
      default:
        return ConnectionInfoUnknown(raw: map);
    }
  }
}

@immutable
final class ConnectionCredentialInfo implements ConnectionInfo {
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


@immutable
final class ConnectionEnvInfo implements ConnectionInfo {
  const ConnectionEnvInfo({
    required this.name,
    required this.status,
  });

  factory ConnectionEnvInfo.fromJson(Map<String, dynamic> json) {
    return ConnectionEnvInfo(
      name: json["name"] as String,
      status: json["status"] == null ? null : ConnectionStatus.fromJson(json["status"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "env",
      "name": name,
      "status": ?status?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ConnectionEnvInfo copyWith({
    String? name,
    ConnectionStatus? status,
  }) {
    return ConnectionEnvInfo(
      name: name ?? this.name,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionEnvInfo &&
          other.name == name &&
          other.status == status);

  @override
  int get hashCode => Object.hash(name, status);

  final String name;
  final ConnectionStatus? status;
}


/// Fallback variant for an unrecognized [ConnectionInfo] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
final class ConnectionInfoUnknown implements ConnectionInfo {
  const ConnectionInfoUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionInfoUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

enum ConnectionCredentialInfoMethod {
  @JsonValue("key")
  key,
  @JsonValue("oauth")
  oauth,
  @JsonValue("external")
  external,

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
      case "external":
        return ConnectionCredentialInfoMethod.external;
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
      case ConnectionCredentialInfoMethod.external:
        return "external";
      case ConnectionCredentialInfoMethod.unknown:
        return 'unknown';
    }
  }
}
