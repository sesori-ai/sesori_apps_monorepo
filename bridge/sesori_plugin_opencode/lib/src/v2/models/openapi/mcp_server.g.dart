// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpServer {
  const McpServer({
    required this.name,
    required this.status,
    required this.integrationID,
  });

  factory McpServer.fromJson(Map<String, dynamic> json) {
    return McpServer(
      name: json["name"] as String,
      status: McpServerStatus.fromJson(json["status"] as Object),
      integrationID: json["integrationID"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "status": status.toJson(),
      "integrationID": ?integrationID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  McpServer copyWith({
    String? name,
    McpServerStatus? status,
    String? integrationID,
  }) {
    return McpServer(
      name: name ?? this.name,
      status: status ?? this.status,
      integrationID: integrationID ?? this.integrationID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServer &&
          other.name == name &&
          other.status == status &&
          other.integrationID == integrationID);

  @override
  int get hashCode => Object.hash(name, status, integrationID);

  final String name;
  final McpServerStatus status;
  final String? integrationID;
}
