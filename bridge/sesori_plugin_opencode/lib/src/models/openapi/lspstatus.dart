// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class LSPStatus {
  const LSPStatus({
    required this.id,
    required this.name,
    required this.root,
    required this.status,
  });

  factory LSPStatus.fromJson(Map<String, dynamic> json) {
    return LSPStatus(
      id: json["id"] as String,
      name: json["name"] as String,
      root: json["root"] as String,
      status: json["status"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "root": root,
      "status": status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LSPStatus &&
          other.id == id &&
          other.name == name &&
          other.root == root &&
          other.status == status);

  @override
  int get hashCode => Object.hash(id, name, root, status);

  final String id;
  final String name;
  final String root;
  final String status;
}
