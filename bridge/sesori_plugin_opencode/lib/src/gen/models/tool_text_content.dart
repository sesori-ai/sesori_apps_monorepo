// GENERATED FILE - DO NOT EDIT BY HAND


class ToolTextContent {
  const ToolTextContent({
    required this.type,
    required this.text,
  });

  factory ToolTextContent.fromJson(Map<String, dynamic> json) {
    return ToolTextContent(
      type: json["type"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "text": text,
    };
  }

  final String type;
  final String text;
}
