// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';
import 'connection_info.g.dart';
import 'connection_status.g.dart';

@immutable
class ConnectionEnvInfo implements ConnectionInfo {
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
