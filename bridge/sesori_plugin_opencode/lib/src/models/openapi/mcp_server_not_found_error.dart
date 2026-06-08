// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.991638Z


class McpServerNotFoundError {
  const McpServerNotFoundError({
    required this.tag,
    required this.name,
    required this.message,
  });

  factory McpServerNotFoundError.fromJson(Map<String, dynamic> json) {
    return McpServerNotFoundError(
      tag: json["_tag"] as String,
      name: json["name"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "name": name,
      "message": message,
    };
  }

  final String tag;
  final String name;
  final String message;
}
