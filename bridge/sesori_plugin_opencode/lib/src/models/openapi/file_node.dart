// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.899667Z


class FileNode {
  const FileNode({
    required this.name,
    required this.path,
    required this.absolute,
    required this.type,
    required this.ignored,
  });

  factory FileNode.fromJson(Map<String, dynamic> json) {
    return FileNode(
      name: json["name"] as String,
      path: json["path"] as String,
      absolute: json["absolute"] as String,
      type: json["type"] as String,
      ignored: json["ignored"] as bool,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "path": path,
      "absolute": absolute,
      "type": type,
      "ignored": ignored,
    };
  }

  final String name;
  final String path;
  final String absolute;
  final String type;
  final bool ignored;
}
