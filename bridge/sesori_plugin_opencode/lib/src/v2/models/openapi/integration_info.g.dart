// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'connection_info.g.dart';
import 'integration_method.g.dart';

@immutable
class IntegrationInfo {
  const IntegrationInfo({
    required this.id,
    required this.name,
    required this.metadata,
    required this.methods,
    required this.connections,
  });

  factory IntegrationInfo.fromJson(Map<String, dynamic> json) {
    return IntegrationInfo(
      id: json["id"] as String,
      name: json["name"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      methods: (json["methods"] as List<dynamic>).map((e) => IntegrationMethod.fromJson(e as Map<String, dynamic>)).toList(),
      connections: (json["connections"] as List<dynamic>).map((e) => ConnectionInfo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "metadata": ?metadata,
      "methods": methods.map((e) => e.toJson()).toList(),
      "connections": connections.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationInfo copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? metadata,
    List<IntegrationMethod>? methods,
    List<ConnectionInfo>? connections,
  }) {
    return IntegrationInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
      methods: methods ?? this.methods,
      connections: connections ?? this.connections,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationInfo &&
          other.id == id &&
          other.name == name &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          const DeepCollectionEquality().equals(other.methods, methods) &&
          const DeepCollectionEquality().equals(other.connections, connections));

  @override
  int get hashCode => Object.hash(id, name, const DeepCollectionEquality().hash(metadata), const DeepCollectionEquality().hash(methods), const DeepCollectionEquality().hash(connections));

  final String id;
  final String name;
  final Map<String, dynamic>? metadata;
  final List<IntegrationMethod> methods;
  final List<ConnectionInfo> connections;
}
