// GENERATED FILE - DO NOT EDIT BY HAND


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
