// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.011860Z


class ToolFileContent {
  const ToolFileContent({
    required this.type,
    required this.source,
    required this.mime,
    this.name,
  });

  factory ToolFileContent.fromJson(Map<String, dynamic> json) {
    return ToolFileContent(
      type: json["type"] as String,
      source: json["source"],
      mime: json["mime"] as String,
      name: json["name"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "source": source,
      "mime": mime,
      "name": ?name,
    };
  }

  final String type;
  final dynamic source;
  final String mime;
  final String? name;
}
