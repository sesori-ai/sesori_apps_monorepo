// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:meta/meta.dart';
import 'mcp_server_status.g.dart';

@immutable
class McpServer {
  const McpServer({
    required this.name,
    required this.status,
    required this.title,
    required this.integrationID,
  });

  factory McpServer.fromJson(Map<String, dynamic> json) {
    return McpServer(
      name: json["name"] as String,
      status: McpServerStatus.fromJson(json["status"] as Object),
      title: json["title"] as String?,
      integrationID: json["integrationID"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "status": status.toJson(),
      "title": ?title,
      "integrationID": ?integrationID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  McpServer copyWith({
    String? name,
    McpServerStatus? status,
    String? title,
    String? integrationID,
  }) {
    return McpServer(
      name: name ?? this.name,
      status: status ?? this.status,
      title: title ?? this.title,
      integrationID: integrationID ?? this.integrationID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McpServer &&
          other.name == name &&
          other.status == status &&
          other.title == title &&
          other.integrationID == integrationID);

  @override
  int get hashCode => Object.hash(name, status, title, integrationID);

  final String name;
  final McpServerStatus status;
  final String? title;
  final String? integrationID;
}
